"""
GEO Insight MVP - 简化版品牌监测工具
主要功能：用户注册登录、上传prompt清单、配置品牌信息和LLM API、批量查询
"""
import os
import pandas as pd
from flask import Flask, render_template, request, flash, redirect, url_for, jsonify, send_file, session, g
from werkzeug.utils import secure_filename
import uuid
import json
import asyncio
import aiohttp
from datetime import datetime
import re
import threading
import time
from database import db
from auth import login_required, get_current_user, create_user_directories, get_user_file_path

app = Flask(__name__)
app.secret_key = 'geo-insight-mvp-secret-key-change-in-production'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# 确保上传目录存在
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('results', exist_ok=True)

# 允许的文件扩展名
ALLOWED_EXTENSIONS = {'csv', 'xlsx', 'xls'}

# 后台任务状态管理
task_status = {}  # {task_id: {'status': 'running|completed|failed', 'processed_count': 0, 'total_count': 0, 'start_time': datetime}}

@app.before_request
def load_user():
    """在每个请求前加载当前用户"""
    g.current_user = get_current_user()

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def parse_uploaded_file(file_path):
    """解析上传的CSV或Excel文件"""
    try:
        if file_path.endswith('.csv'):
            df = pd.read_csv(file_path)
        else:
            df = pd.read_excel(file_path)
        
        # 假设第一列是prompts
        if len(df.columns) > 0:
            prompts = df.iloc[:, 0].dropna().tolist()
            return prompts
        return []
    except Exception as e:
        print(f"文件解析错误: {e}")
        return []

async def query_llm_api(session, prompt, api_config):
    """异步查询LLM API"""
    try:
        # 基础请求头
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'GEO-Insight-MVP/1.0'
        }
        
        # 添加认证头
        if api_config.get('api_key'):
            if 'xeduapi' in api_config['endpoint'].lower():
                headers['Authorization'] = f'Bearer {api_config["api_key"]}'
            elif 'openai' in api_config['endpoint'].lower():
                headers['Authorization'] = f'Bearer {api_config["api_key"]}'
            elif 'claude' in api_config['endpoint'].lower() or 'anthropic' in api_config['endpoint'].lower():
                headers['x-api-key'] = api_config["api_key"]
                headers['anthropic-version'] = '2023-06-01'
            else:
                headers['Authorization'] = f'Bearer {api_config["api_key"]}'
        
        # 根据不同的API类型构造请求体
        if 'openai' in api_config['endpoint'].lower():
            data = {
                'model': api_config.get('model', 'gpt-3.5-turbo'),
                'messages': [{'role': 'user', 'content': prompt}],
                'max_tokens': 500,
                'temperature': 0.7
            }
        elif 'claude' in api_config['endpoint'].lower() or 'anthropic' in api_config['endpoint'].lower():
            data = {
                'model': api_config.get('model', 'claude-3-sonnet-20240229'),
                'max_tokens': 500,
                'messages': [{'role': 'user', 'content': prompt}]
            }
        elif 'xeduapi' in api_config['endpoint'].lower():
            # XeduAPI格式
            data = {
                'model': api_config.get('model', 'gpt-3.5-turbo'),
                'messages': [{'role': 'user', 'content': prompt}],
                'max_tokens': 500,
                'temperature': 0.7,
                'stream': False
            }
        else:
            # 通用格式 - 尝试多种可能的格式
            data = {
                'model': api_config.get('model', 'gpt-3.5-turbo'),
                'messages': [{'role': 'user', 'content': prompt}],
                'max_tokens': 500,
                'prompt': prompt  # 备用字段
            }
        
        print(f"发送请求到: {api_config['endpoint']}")
        print(f"请求头: {headers}")
        print(f"请求数据: {data}")
        
        async with session.post(
            api_config['endpoint'], 
            json=data, 
            headers=headers,
            timeout=aiohttp.ClientTimeout(total=30)
        ) as response:
            
            print(f"响应状态: {response.status}")
            print(f"响应头: {dict(response.headers)}")
            
            # 获取响应内容
            response_text = await response.text()
            print(f"响应内容前200字符: {response_text[:200]}")
            
            if response.status == 200:
                # 检查响应类型
                content_type = response.headers.get('content-type', '').lower()
                
                if 'application/json' in content_type:
                    try:
                        result = await response.json()
                        
                        # 提取回复内容 - 支持多种格式
                        content = None
                        
                        # OpenAI格式
                        if 'choices' in result and len(result['choices']) > 0:
                            if 'message' in result['choices'][0]:
                                content = result['choices'][0]['message']['content']
                            elif 'text' in result['choices'][0]:
                                content = result['choices'][0]['text']
                        
                        # Claude格式
                        elif 'content' in result:
                            if isinstance(result['content'], list) and len(result['content']) > 0:
                                content = result['content'][0].get('text', str(result['content'][0]))
                            else:
                                content = str(result['content'])
                        
                        # 其他可能的格式
                        elif 'response' in result:
                            content = result['response']
                        elif 'text' in result:
                            content = result['text']
                        elif 'output' in result:
                            content = result['output']
                        else:
                            content = str(result)
                        
                        if content:
                            return {
                                'prompt': prompt,
                                'response': content,
                                'status': 'success'
                            }
                        else:
                            return {
                                'prompt': prompt,
                                'response': f'无法解析API响应: {str(result)}',
                                'status': 'error'
                            }
                            
                    except json.JSONDecodeError as e:
                        return {
                            'prompt': prompt,
                            'response': f'JSON解析失败: {str(e)}. 响应内容: {response_text[:200]}',
                            'status': 'error'
                        }
                else:
                    return {
                        'prompt': prompt,
                        'response': f'API返回非JSON格式 (Content-Type: {content_type}). 响应: {response_text[:200]}',
                        'status': 'error'
                    }
            else:
                return {
                    'prompt': prompt,
                    'response': f'API调用失败 - 状态码: {response.status}, 响应: {response_text[:200]}',
                    'status': 'error'
                }
                
    except aiohttp.ClientError as e:
        return {
            'prompt': prompt,
            'response': f'网络请求错误: {str(e)}',
            'status': 'error'
        }
    except Exception as e:
        return {
            'prompt': prompt,
            'response': f'请求错误: {str(e)}',
            'status': 'error'
        }

def analyze_brand_mentions(response_text, brands, domains):
    """分析回复中的品牌和域名提及（二元计数：0或1）"""
    mentions = {
        'brands': {},
        'domains': {},
        'has_brand_mention': False,   # 是否提及任何品牌
        'has_domain_mention': False,  # 是否提及任何域名
        'total_brand_mentions': 0,    # 提及的品牌数量
        'total_domain_mentions': 0    # 提及的域名数量
    }
    
    response_lower = response_text.lower()
    
    # 检查品牌名提及（二元：0或1）
    for brand in brands:
        if brand.lower() in response_lower:
            mentions['brands'][brand] = 1
            mentions['has_brand_mention'] = True
            mentions['total_brand_mentions'] += 1
        else:
            mentions['brands'][brand] = 0
    
    # 检查域名提及（二元：0或1）
    for domain in domains:
        if domain.lower() in response_lower:
            mentions['domains'][domain] = 1
            mentions['has_domain_mention'] = True
            mentions['total_domain_mentions'] += 1
        else:
            mentions['domains'][domain] = 0
    
    return mentions

async def batch_query_llms(prompts, api_config, brands, domains, task_id, concurrency=3, request_delay=0.5):
    """批量查询LLM并分析结果，支持进度更新"""
    results = []
    
    # 初始化任务状态
    task_status[task_id] = {
        'status': 'running',
        'processed_count': 0,
        'total_count': len(prompts),
        'start_time': datetime.now()
    }
    
    # 创建信号量来控制并发数
    semaphore = asyncio.Semaphore(concurrency)
    
    async def query_with_semaphore(session, prompt, index):
        async with semaphore:
            result = await query_llm_api(session, prompt, api_config)
            # 更新进度
            task_status[task_id]['processed_count'] = index + 1
            # 添加请求延迟
            if request_delay > 0:
                await asyncio.sleep(request_delay)
            return result
    
    async with aiohttp.ClientSession() as session:
        tasks = [query_with_semaphore(session, prompt, i) for i, prompt in enumerate(prompts)]
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, response in enumerate(responses):
            if isinstance(response, Exception):
                # 处理异常情况
                result = {
                    'prompt': prompts[i],
                    'response': f'查询异常: {str(response)}',
                    'status': 'error',
                    'analysis': {
                        'brands': {brand: 0 for brand in brands},
                        'domains': {domain: 0 for domain in domains},
                        'has_brand_mention': False,
                        'has_domain_mention': False,
                        'total_brand_mentions': 0,
                        'total_domain_mentions': 0
                    }
                }
            else:
                if response['status'] == 'success':
                    mentions = analyze_brand_mentions(response['response'], brands, domains)
                    response['analysis'] = mentions
                else:
                    response['analysis'] = {
                        'brands': {brand: 0 for brand in brands},
                        'domains': {domain: 0 for domain in domains},
                        'has_brand_mention': False,
                        'has_domain_mention': False,
                        'total_brand_mentions': 0,
                        'total_domain_mentions': 0
                    }
                result = response
            
            results.append(result)
    
    return results

# 用户认证路由
@app.route('/')
def index():
    if g.current_user:
        return redirect(url_for('dashboard'))
    return render_template('index.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # 验证输入
        if not all([username, email, password, confirm_password]):
            flash('请填写所有字段')
            return render_template('register.html')
        
        if password != confirm_password:
            flash('两次输入的密码不一致')
            return render_template('register.html')
        
        if len(password) < 6:
            flash('密码长度至少6位')
            return render_template('register.html')
        
        # 尝试创建用户
        user_id = db.create_user(username, email, password)
        if user_id:
            # 创建用户目录
            create_user_directories(user_id)
            flash('注册成功，请登录')
            return redirect(url_for('login'))
        else:
            flash('用户名或邮箱已存在')
            return render_template('register.html')
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        
        if not all([username, password]):
            flash('请填写用户名和密码')
            return render_template('login.html')
        
        user = db.authenticate_user(username, password)
        if user:
            session['user_id'] = user['id']
            session['username'] = user['username']
            flash(f'欢迎回来，{user["username"]}！')
            return redirect(url_for('dashboard'))
        else:
            flash('用户名或密码错误')
            return render_template('login.html')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('已成功登出')
    return redirect(url_for('index'))

@app.route('/dashboard')
@login_required
def dashboard():
    """用户仪表板"""
    # 获取用户的查询历史
    history = db.get_user_query_history(g.current_user['id'], limit=10)
    
    # 获取用户的API配置
    api_configs = db.get_user_api_configs(g.current_user['id'])
    
    return render_template('dashboard.html', 
                         user=g.current_user, 
                         history=history, 
                         api_configs=api_configs)

@app.route('/profile')
@login_required
def profile():
    """用户资料页面"""
    api_configs = db.get_user_api_configs(g.current_user['id'])
    brand_configs = db.get_user_brand_configs(g.current_user['id'])
    
    return render_template('profile.html', 
                         user=g.current_user,
                         api_configs=api_configs,
                         brand_configs=brand_configs)

@app.route('/change_password', methods=['POST'])
@login_required
def change_password():
    """修改密码"""
    current_password = request.form.get('current_password', '').strip()
    new_password = request.form.get('new_password', '').strip()
    confirm_password = request.form.get('confirm_password', '').strip()
    
    # 验证输入
    if not all([current_password, new_password, confirm_password]):
        flash('请填写所有字段')
        return redirect(url_for('profile'))
    
    if new_password != confirm_password:
        flash('新密码与确认密码不匹配')
        return redirect(url_for('profile'))
    
    if len(new_password) < 6:
        flash('新密码长度至少6位')
        return redirect(url_for('profile'))
    
    # 修改密码
    success, message = db.change_password(g.current_user['id'], current_password, new_password)
    
    if success:
        flash(message, 'success')
    else:
        flash(message, 'error')
    
    return redirect(url_for('profile'))

@app.route('/api_configs', methods=['GET', 'POST'])
@login_required
def api_configs():
    """API配置管理"""
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        endpoint = request.form.get('endpoint', '').strip()
        api_key = request.form.get('api_key', '').strip()
        model = request.form.get('model', '').strip()
        is_default = request.form.get('is_default') == 'on'
        
        if not all([name, endpoint, api_key]):
            flash('请填写配置名称、API端点和密钥')
            return redirect(url_for('api_configs'))
        
        config_id = db.save_api_config(
            g.current_user['id'], name, endpoint, api_key, model, is_default
        )
        
        if config_id:
            flash('API配置保存成功')
        else:
            flash('保存失败，请重试')
        
        return redirect(url_for('api_configs'))
    
    configs = db.get_user_api_configs(g.current_user['id'])
    return render_template('api_configs.html', configs=configs)

@app.route('/api_config/set_default/<int:config_id>', methods=['POST'])
@login_required
def set_default_api_config(config_id):
    """设置默认API配置"""
    if db.set_default_api_config(config_id, g.current_user['id']):
        return jsonify({'success': True, 'message': '已设置为默认配置'})
    else:
        return jsonify({'success': False, 'message': '设置失败'}), 400

@app.route('/api_config/delete/<int:config_id>', methods=['DELETE'])
@login_required
def delete_api_config(config_id):
    """删除API配置"""
    if db.delete_api_config(config_id, g.current_user['id']):
        return jsonify({'success': True, 'message': '配置已删除'})
    else:
        return jsonify({'success': False, 'message': '删除失败，该配置可能正在被使用'}), 400

@app.route('/new_task')
@login_required
def new_task():
    """创建新任务页面"""
    api_configs = db.get_user_api_configs(g.current_user['id'])
    brand_configs = db.get_user_brand_configs(g.current_user['id'])
    
    return render_template('new_task.html', 
                         api_configs=api_configs,
                         brand_configs=brand_configs)

@app.route('/upload', methods=['POST'])
@login_required
def upload_file():
    try:
        if 'file' not in request.files:
            flash('请选择文件')
            return redirect(url_for('new_task'))
        
        file = request.files['file']
        if file.filename == '':
            flash('未选择文件')
            return redirect(url_for('new_task'))
        
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            unique_filename = f"{uuid.uuid4()}_{filename}"
            
            # 保存到用户专属目录
            user_upload_dir, _ = create_user_directories(g.current_user['id'])
            file_path = os.path.join(user_upload_dir, unique_filename)
            
            # 保存文件
            file.save(file_path)
            
            # 解析prompts
            prompts = parse_uploaded_file(file_path)
            
            if not prompts:
                flash('文件解析失败或文件为空')
                return redirect(url_for('new_task'))
            
            # 获取用户的API和品牌配置
            api_configs = db.get_user_api_configs(g.current_user['id'])
            brand_configs = db.get_user_brand_configs(g.current_user['id'])
            
            return render_template('configure.html', 
                                 prompts=prompts[:10],  # 只显示前10个预览
                                 total_prompts=len(prompts),
                                 file_path=unique_filename,
                                 api_configs=api_configs,
                                 brand_configs=brand_configs)
        
        flash('不支持的文件格式，请上传CSV或Excel文件')
        return redirect(url_for('new_task'))
        
    except Exception as e:
        # 添加详细的错误日志
        print(f"上传文件错误: {str(e)}")
        import traceback
        traceback.print_exc()
        flash(f'文件上传失败: {str(e)}')
        return redirect(url_for('new_task'))

@app.route('/test_api', methods=['POST'])
@login_required
def test_api():
    """测试API连接"""
    try:
        # 从表单或已保存的配置中获取API信息
        config_id = request.form.get('config_id')
        if config_id:
            # 使用已保存的配置
            api_config = db.get_api_config(config_id, g.current_user['id'])
            if not api_config:
                return jsonify({'success': False, 'message': '配置不存在'})
        else:
            # 使用表单中的临时配置
            api_config = {
                'endpoint': request.form.get('api_endpoint'),
                'api_key': request.form.get('api_key'),
                'model': request.form.get('model', '')
            }
        
        if not all([api_config['endpoint'], api_config['api_key']]):
            return jsonify({'success': False, 'message': '请填写API端点和密钥'})
        
        # 使用简单的测试prompt
        test_prompt = "请简单回复'测试成功'"
        
        # 异步测试API
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        async def test_single_api():
            async with aiohttp.ClientSession() as session:
                result = await query_llm_api(session, test_prompt, api_config)
                return result
        
        result = loop.run_until_complete(test_single_api())
        loop.close()
        
        if result['status'] == 'success':
            return jsonify({
                'success': True, 
                'message': 'API连接成功！',
                'response': result['response'][:100] + '...' if len(result['response']) > 100 else result['response']
            })
        else:
            return jsonify({
                'success': False, 
                'message': f'API连接失败: {result["response"]}'
            })
            
    except Exception as e:
        return jsonify({'success': False, 'message': f'测试失败: {str(e)}'})

@app.route('/run_analysis', methods=['POST'])
@login_required
def run_analysis():
    try:
        # 检查是否有文件上传
        if 'file' in request.files:
            # 处理文件上传
            file = request.files['file']
            if file.filename == '':
                flash('未选择文件')
                return redirect(url_for('upload_page'))
            
            if file and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                unique_filename = f"{uuid.uuid4()}_{filename}"
                
                # 保存到用户专属目录
                user_upload_dir, _ = create_user_directories(g.current_user['id'])
                file_path = os.path.join(user_upload_dir, unique_filename)
                
                # 保存文件
                file.save(file_path)
                file_path = unique_filename  # 用于后续处理
            else:
                flash('不支持的文件格式，请上传CSV或Excel文件')
                return redirect(url_for('upload_page'))
        else:
            # 从表单获取已上传的文件路径
            file_path = request.form.get('file_path')
            if not file_path:
                flash('请选择文件')
                return redirect(url_for('upload_page'))
        
        # 获取表单数据
        task_name = request.form.get('task_name', f'任务_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
        
        # 品牌配置
        brands = [b.strip() for b in request.form.get('brands', '').split(',') if b.strip()]
        domains = [d.strip() for d in request.form.get('domains', '').split(',') if d.strip()]
        
        # 保存品牌配置
        if brands or domains:
            brand_config_id = db.save_brand_config(g.current_user['id'], brands, domains)
        else:
            brand_config_id = None
        
        # API配置
        api_config_id = request.form.get('api_config')
        if api_config_id:
            # 使用保存的API配置
            api_config = db.get_api_config(api_config_id, g.current_user['id'])
            if not api_config:
                flash('API配置不存在')
                return redirect(url_for('upload_page'))
        else:
            flash('请选择API配置')
            return redirect(url_for('upload_page'))
        
        # 获取并发设置
        concurrency = int(request.form.get('max_concurrent', 3))
        timeout = int(request.form.get('timeout', 30))
        request_delay = 0.5  # 固定延迟时间
        
        # 验证必填字段
        if not file_path or not api_config:
            flash('请选择文件和API配置')
            return redirect(url_for('upload_page'))
        
        if not brands and not domains:
            flash('请至少输入一个品牌名称或域名进行监测')
            return redirect(url_for('upload_page'))
        
        # 重新解析prompts（从用户目录）
        user_upload_dir, user_results_dir = create_user_directories(g.current_user['id'])
        full_file_path = os.path.join(user_upload_dir, file_path)
        prompts = parse_uploaded_file(full_file_path)
        
        if not prompts:
            flash('无法解析prompts文件')
            return redirect(url_for('upload_page'))
        
        # 创建查询任务记录
        task_id = db.create_query_task(
            g.current_user['id'], task_name, file_path, len(prompts), 
            api_config_id, brand_config_id
        )
        
        # 限制查询数量（MVP版本）
        max_prompts = 20
        if len(prompts) > max_prompts:
            prompts = prompts[:max_prompts]
            flash(f'为了演示，只处理前{max_prompts}个prompts')
        
        # 启动后台任务
        thread = threading.Thread(
            target=run_analysis_background,
            args=(task_id, prompts, api_config, brands, domains, g.current_user['id'], task_name, concurrency, request_delay)
        )
        thread.daemon = True
        thread.start()
        
        # 跳转到等待页面
        return redirect(url_for('processing_page', task_id=task_id))
        
    except Exception as e:
        flash(f'启动分析任务失败: {str(e)}')
        return redirect(url_for('upload_page'))

@app.route('/results/<result_id>')
@login_required
def view_results(result_id):
    try:
        # 验证用户权限
        task = db.get_query_task(result_id, g.current_user['id'])
        if not task:
            flash('任务不存在或无权访问')
            return redirect(url_for('dashboard'))
        
        # 读取结果文件
        user_upload_dir, user_results_dir = create_user_directories(g.current_user['id'])
        result_file = os.path.join(user_results_dir, f'{result_id}.json')
        
        with open(result_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        return render_template('results.html', data=data, result_id=result_id, task=task)
    except FileNotFoundError:
        flash('结果文件未找到')
        return redirect(url_for('dashboard'))
    except Exception as e:
        flash(f'加载结果失败: {str(e)}')
        return redirect(url_for('dashboard'))

@app.route('/download/<result_id>')
@login_required
def download_results(result_id):
    try:
        # 验证用户权限
        task = db.get_query_task(result_id, g.current_user['id'])
        if not task:
            flash('任务不存在或无权访问')
            return redirect(url_for('dashboard'))
        
        # 读取结果文件
        user_upload_dir, user_results_dir = create_user_directories(g.current_user['id'])
        result_file = os.path.join(user_results_dir, f'{result_id}.json')
        
        with open(result_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 转换为CSV格式
        csv_data = []
        for result in data['results']:
            row = {
                'Prompt': result['prompt'],
                'Response': result['response'][:200] + '...' if len(result['response']) > 200 else result['response'],
                'Status': result['status'],
                'Has_Brand_Mention': 1 if result['analysis']['has_brand_mention'] else 0,
                'Has_Domain_Mention': 1 if result['analysis']['has_domain_mention'] else 0,
                'Brand_Mention_Count': result['analysis']['total_brand_mentions'],
                'Domain_Mention_Count': result['analysis']['total_domain_mentions']
            }
            
            # 添加品牌提及列
            for brand in data['brands']:
                row[f'Brand_{brand}'] = result['analysis']['brands'].get(brand, 0)
            
            # 添加域名提及列
            for domain in data['domains']:
                row[f'Domain_{domain}'] = result['analysis']['domains'].get(domain, 0)
            
            csv_data.append(row)
        
        df = pd.DataFrame(csv_data)
        csv_file = os.path.join(user_results_dir, f'{result_id}.csv')
        df.to_csv(csv_file, index=False, encoding='utf-8-sig')
        
        return send_file(csv_file, as_attachment=True, download_name=f'geo_insight_results_{result_id}.csv')
        
    except Exception as e:
        flash(f'下载失败: {str(e)}')
        return redirect(url_for('dashboard'))

@app.route('/history')
@login_required
def history():
    """查询历史页面"""
    history = db.get_user_query_history(g.current_user['id'], limit=50)
    return render_template('history.html', history=history)

# API路由 - 查询任务状态
@app.route('/api/task_status/<task_id>')
@login_required
def get_task_status(task_id):
    """获取任务状态API"""
    try:
        # 检查任务是否属于当前用户
        task_info = db.get_query_task(task_id, g.current_user['id'])
        if not task_info:
            return jsonify({'error': '任务不存在'}), 404
        
        # 从内存中获取实时状态
        if task_id in task_status:
            status_info = task_status[task_id].copy()
            # 计算已运行时间
            elapsed_time = (datetime.now() - status_info['start_time']).total_seconds()
            status_info['elapsed_time'] = round(elapsed_time, 1)
            status_info['start_time'] = status_info['start_time'].isoformat()
            return jsonify(status_info)
        else:
            # 从数据库获取状态
            return jsonify({
                'status': task_info.get('status', 'unknown'),
                'processed_count': task_info.get('completed_prompts', 0),
                'total_count': task_info.get('total_prompts', 0)
            })
            
    except Exception as e:
        return jsonify({'error': f'获取任务状态失败: {str(e)}'}), 500

def run_analysis_background(task_id, prompts, api_config, brands, domains, user_id, task_name, concurrency=3, request_delay=0.5):
    """在后台运行分析任务"""
    try:
        # 异步执行批量查询
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        results = loop.run_until_complete(
            batch_query_llms(prompts, api_config, brands, domains, task_id, concurrency, request_delay)
        )
        loop.close()
        
        # 保存结果到用户目录
        user_upload_dir, user_results_dir = create_user_directories(user_id)
        result_filename = f'{task_id}.json'
        result_file = os.path.join(user_results_dir, result_filename)
        
        # 计算统计信息
        successful_results = [r for r in results if r['status'] == 'success']
        total_responses = len(successful_results)
        
        # 计算品牌提及统计
        brand_mention_count = sum(1 for r in successful_results if r['analysis']['has_brand_mention'])
        domain_mention_count = sum(1 for r in successful_results if r['analysis']['has_domain_mention'])
        
        # 计算每个品牌的提及率
        brand_stats = {}
        for brand in brands:
            mention_count = sum(1 for r in successful_results if r['analysis']['brands'].get(brand, 0) == 1)
            brand_stats[brand] = {
                'mention_count': mention_count,
                'mention_rate': round(mention_count / total_responses * 100, 2) if total_responses > 0 else 0
            }
        
        # 计算每个域名的提及率
        domain_stats = {}
        for domain in domains:
            mention_count = sum(1 for r in successful_results if r['analysis']['domains'].get(domain, 0) == 1)
            domain_stats[domain] = {
                'mention_count': mention_count,
                'mention_rate': round(mention_count / total_responses * 100, 2) if total_responses > 0 else 0
            }

        analysis_summary = {
            'task_id': task_id,
            'task_name': task_name,
            'user_id': user_id,
            'total_prompts': len(prompts),
            'successful_queries': total_responses,
            'brand_mention_count': brand_mention_count,  # 有品牌提及的回答数量
            'domain_mention_count': domain_mention_count,  # 有域名提及的回答数量
            'total_brand_mentions': brand_mention_count,  # 为了模板兼容性
            'total_domain_mentions': domain_mention_count,  # 为了模板兼容性
            'brand_mention_rate': round(brand_mention_count / total_responses * 100, 2) if total_responses > 0 else 0,
            'domain_mention_rate': round(domain_mention_count / total_responses * 100, 2) if total_responses > 0 else 0,
            'brands': brands,
            'domains': domains,
            'brand_stats': brand_stats,
            'domain_stats': domain_stats,
            'timestamp': datetime.now().isoformat(),
            'settings': {
                'concurrency': concurrency,
                'request_delay': request_delay,
                'api_endpoint': api_config['endpoint'],
                'model': api_config.get('model', 'default')
            },
            'results': results
        }
        
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(analysis_summary, f, ensure_ascii=False, indent=2)
        
        # 更新任务状态
        db.update_query_task(
            task_id, 
            completed_prompts=len(results),
            status='completed',
            results_file=result_filename,
            completed_at=datetime.now().isoformat()
        )
        
        # 更新内存中的任务状态
        if task_id in task_status:
            task_status[task_id]['status'] = 'completed'
        
    except Exception as e:
        print(f"后台任务执行失败: {e}")
        # 更新任务状态为失败
        if task_id in task_status:
            task_status[task_id]['status'] = 'failed'
        
        db.update_query_task(
            task_id, 
            status='failed',
            completed_at=datetime.now().isoformat()
        )

@app.route('/processing/<task_id>')
@login_required
def processing_page(task_id):
    """显示任务处理等待页面"""
    try:
        # 验证任务权限
        task = db.get_query_task(task_id, g.current_user['id'])
        if not task:
            flash('任务不存在或无权访问')
            return redirect(url_for('dashboard'))
        
        # 获取任务信息
        task_name = task.get('task_name', '分析任务')
        total_prompts = task.get('total_prompts', 0)
        
        # 初始化品牌和域名列表
        brands = []
        domains = []
        
        # 获取品牌和域名配置
        brand_config_id = task.get('brand_config_id')
        
        if brand_config_id:
            try:
                brand_config = db.get_brand_config(brand_config_id, g.current_user['id'])
                
                if brand_config:
                    brands = brand_config.get('brands', [])
                    domains = brand_config.get('domains', [])
                    
                    # 确保brands和domains是列表
                    if not isinstance(brands, list):
                        brands = []
                    if not isinstance(domains, list):
                        domains = []
                        
            except Exception as e:
                print(f"获取品牌配置失败: {e}")
                brands = []
                domains = []
        
        # 预估完成时间（粗略估算：每个prompt 2秒 + 并发优化）
        estimated_time = max(1, round(total_prompts * 2 / 3 / 60, 1))  # 假设3个并发
        
        return render_template('processing.html',
                             task_id=task_id,
                             task_name=task_name,
                             total_prompts=total_prompts,
                             brand_count=len(brands),
                             domain_count=len(domains),
                             estimated_time=estimated_time)
                             
    except Exception as e:
        print(f"Processing page error: {e}")
        import traceback
        traceback.print_exc()
        flash(f'加载等待页面失败: {str(e)}')
        return redirect(url_for('dashboard'))

@app.route('/upload', methods=['GET'])
@login_required
def upload_page():
    """上传和配置页面"""
    api_configs = db.get_user_api_configs(g.current_user['id'])
    brand_configs = db.get_user_brand_configs(g.current_user['id'])
    
    return render_template('upload.html', 
                         api_configs=api_configs,
                         brand_configs=brand_configs)

if __name__ == '__main__':
    # 在生产环境中，这里会被注释掉，使用 gunicorn 启动
    app.run(debug=True, host='0.0.0.0', port=5000)
