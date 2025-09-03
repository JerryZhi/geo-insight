"""
数据库模型和用户管理
"""
import sqlite3
import hashlib
import uuid
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
import json

class Database:
    def __init__(self, db_path='geo_insight.db'):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """初始化数据库表"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 用户表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL,
                last_login TEXT,
                is_active INTEGER DEFAULT 1
            )
        ''')
        
        # API配置表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS api_configs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                api_key TEXT NOT NULL,
                model TEXT,
                is_default INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # 品牌配置表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS brand_configs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                brand_names TEXT NOT NULL,
                website_domains TEXT,
                competitors TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # 查询历史表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS query_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                task_id TEXT UNIQUE NOT NULL,
                task_name TEXT,
                prompts_file TEXT,
                total_prompts INTEGER,
                completed_prompts INTEGER DEFAULT 0,
                status TEXT DEFAULT 'pending',
                api_config_id INTEGER,
                brand_config_id INTEGER,
                results_file TEXT,
                created_at TEXT NOT NULL,
                completed_at TEXT,
                FOREIGN KEY (user_id) REFERENCES users (id),
                FOREIGN KEY (api_config_id) REFERENCES api_configs (id),
                FOREIGN KEY (brand_config_id) REFERENCES brand_configs (id)
            )
        ''')
        
        # 会话表（简单的session管理）
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                session_token TEXT UNIQUE NOT NULL,
                expires_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def get_connection(self):
        """获取数据库连接，带重试机制"""
        import time
        max_retries = 3
        
        for attempt in range(max_retries):
            try:
                conn = sqlite3.connect(self.db_path, timeout=30.0)
                conn.row_factory = sqlite3.Row  # 使结果可以像字典一样访问
                # 启用WAL模式以提高并发性能
                conn.execute('PRAGMA journal_mode=WAL')
                conn.execute('PRAGMA busy_timeout=30000')  # 30秒超时
                return conn
            except sqlite3.OperationalError as e:
                if "database is locked" in str(e) and attempt < max_retries - 1:
                    time.sleep(0.1 * (attempt + 1))  # 递增延迟
                    continue
                raise e
    
    # 上下文管理器方法
    def __enter__(self):
        """上下文管理器入口"""
        self.conn = self.get_connection()
        return self.conn
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """上下文管理器出口"""
        if hasattr(self, 'conn') and self.conn:
            if exc_type is None:
                self.conn.commit()
            else:
                self.conn.rollback()
            self.conn.close()
    
    # 用户管理方法
    def create_user(self, username, email, password):
        """创建新用户"""
        password_hash = generate_password_hash(password)
        created_at = datetime.now().isoformat()
        
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                'INSERT INTO users (username, email, password_hash, created_at) VALUES (?, ?, ?, ?)',
                (username, email, password_hash, created_at)
            )
            user_id = cursor.lastrowid
            conn.commit()
            return user_id
        except sqlite3.IntegrityError as e:
            print(f"用户创建失败: {e}")
            return None
        except Exception as e:
            print(f"数据库错误: {e}")
            return None
        finally:
            conn.close()
    
    def authenticate_user(self, username, password):
        """验证用户登录"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            user = cursor.execute(
                'SELECT * FROM users WHERE username = ? AND is_active = 1',
                (username,)
            ).fetchone()
            
            if user and check_password_hash(user['password_hash'], password):
                # 在同一个连接中更新最后登录时间
                cursor.execute(
                    'UPDATE users SET last_login = ? WHERE id = ?',
                    (datetime.now().isoformat(), user['id'])
                )
                conn.commit()
                return dict(user)
            return None
        except Exception as e:
            print(f"数据库认证错误: {e}")
            return None
        finally:
            conn.close()
    
    def get_user_by_id(self, user_id):
        """根据ID获取用户信息"""
        conn = self.get_connection()
        cursor = conn.cursor()
        user = cursor.execute(
            'SELECT * FROM users WHERE id = ? AND is_active = 1',
            (user_id,)
        ).fetchone()
        conn.close()
        return dict(user) if user else None
    
    # Session管理
    def create_session(self, user_id):
        """创建用户会话"""
        session_token = str(uuid.uuid4())
        created_at = datetime.now().isoformat()
        # Session 7天过期
        expires_at = datetime.now().replace(hour=23, minute=59, second=59).isoformat()
        
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO user_sessions (user_id, session_token, expires_at, created_at) VALUES (?, ?, ?, ?)',
            (user_id, session_token, expires_at, created_at)
        )
        conn.commit()
        conn.close()
        return session_token
    
    def get_user_by_session(self, session_token):
        """根据session token获取用户"""
        conn = self.get_connection()
        cursor = conn.cursor()
        result = cursor.execute('''
            SELECT u.* FROM users u
            JOIN user_sessions s ON u.id = s.user_id
            WHERE s.session_token = ? AND s.expires_at > ? AND u.is_active = 1
        ''', (session_token, datetime.now().isoformat())).fetchone()
        conn.close()
        return dict(result) if result else None
    
    def delete_session(self, session_token):
        """删除会话（登出）"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM user_sessions WHERE session_token = ?', (session_token,))
        conn.commit()
        conn.close()
    
    def change_password(self, user_id, old_password, new_password):
        """修改用户密码"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            # 首先验证旧密码
            user = cursor.execute(
                'SELECT password_hash FROM users WHERE id = ?',
                (user_id,)
            ).fetchone()
            
            if not user:
                return False, "用户不存在"
            
            if not check_password_hash(user[0], old_password):
                return False, "当前密码错误"
            
            # 更新密码
            new_password_hash = generate_password_hash(new_password)
            cursor.execute(
                'UPDATE users SET password_hash = ? WHERE id = ?',
                (new_password_hash, user_id)
            )
            
            conn.commit()
            return True, "密码修改成功"
        except Exception as e:
            conn.rollback()
            return False, f"密码修改失败: {str(e)}"
        finally:
            conn.close()
    
    # API配置管理
    def save_api_config(self, user_id, name, endpoint, api_key, model=None, is_default=False):
        """保存API配置"""
        created_at = datetime.now().isoformat()
        
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # 如果设置为默认，先取消其他默认配置
        if is_default:
            cursor.execute(
                'UPDATE api_configs SET is_default = 0 WHERE user_id = ?',
                (user_id,)
            )
        
        cursor.execute('''
            INSERT INTO api_configs (user_id, name, endpoint, api_key, model, is_default, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, name, endpoint, api_key, model, int(is_default), created_at))
        
        config_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return config_id
    
    def get_user_api_configs(self, user_id):
        """获取用户的API配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        configs = cursor.execute(
            'SELECT * FROM api_configs WHERE user_id = ? ORDER BY is_default DESC, created_at DESC',
            (user_id,)
        ).fetchall()
        conn.close()
        return [dict(config) for config in configs]
    
    def get_api_config(self, config_id, user_id):
        """获取特定的API配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        config = cursor.execute(
            'SELECT * FROM api_configs WHERE id = ? AND user_id = ?',
            (config_id, user_id)
        ).fetchone()
        conn.close()
        return dict(config) if config else None
    
    def set_default_api_config(self, config_id, user_id):
        """设置默认API配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            # 验证配置是否属于用户
            config = cursor.execute(
                'SELECT id FROM api_configs WHERE id = ? AND user_id = ?',
                (config_id, user_id)
            ).fetchone()
            
            if not config:
                return False
            
            # 取消其他默认配置
            cursor.execute(
                'UPDATE api_configs SET is_default = 0 WHERE user_id = ?',
                (user_id,)
            )
            
            # 设置新的默认配置
            cursor.execute(
                'UPDATE api_configs SET is_default = 1 WHERE id = ? AND user_id = ?',
                (config_id, user_id)
            )
            
            conn.commit()
            return True
        except Exception as e:
            conn.rollback()
            return False
        finally:
            conn.close()
    
    def delete_api_config(self, config_id, user_id):
        """删除API配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            # 检查是否有正在使用此配置的任务
            in_use = cursor.execute(
                'SELECT COUNT(*) FROM query_history WHERE api_config_id = ?',
                (config_id,)
            ).fetchone()[0]
            
            if in_use > 0:
                return False  # 配置正在被使用，不能删除
            
            # 删除配置
            cursor.execute(
                'DELETE FROM api_configs WHERE id = ? AND user_id = ?',
                (config_id, user_id)
            )
            
            conn.commit()
            return cursor.rowcount > 0
        except Exception as e:
            conn.rollback()
            return False
        finally:
            conn.close()
    
    # 品牌配置管理
    def save_brand_config(self, user_id, brand_names, website_domains=None, competitors=None):
        """保存品牌配置"""
        created_at = datetime.now().isoformat()
        
        # 转换为JSON字符串存储
        brand_names_str = json.dumps(brand_names) if isinstance(brand_names, list) else brand_names
        website_domains_str = json.dumps(website_domains) if isinstance(website_domains, list) else website_domains
        competitors_str = json.dumps(competitors) if isinstance(competitors, list) else competitors
        
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO brand_configs (user_id, brand_names, website_domains, competitors, created_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, brand_names_str, website_domains_str, competitors_str, created_at))
        
        config_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return config_id
    
    def get_user_brand_configs(self, user_id):
        """获取用户的品牌配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        configs = cursor.execute(
            'SELECT * FROM brand_configs WHERE user_id = ? ORDER BY created_at DESC',
            (user_id,)
        ).fetchall()
        conn.close()
        
        # 解析JSON字段
        result = []
        for config in configs:
            config_dict = dict(config)
            try:
                config_dict['brand_names'] = json.loads(config_dict['brand_names']) if config_dict['brand_names'] else []
                config_dict['website_domains'] = json.loads(config_dict['website_domains']) if config_dict['website_domains'] else []
                config_dict['competitors'] = json.loads(config_dict['competitors']) if config_dict['competitors'] else []
            except:
                pass
            result.append(config_dict)
        
        return result
    
    def get_brand_config(self, config_id, user_id):
        """获取品牌配置"""
        conn = self.get_connection()
        cursor = conn.cursor()
        config = cursor.execute(
            'SELECT * FROM brand_configs WHERE id = ? AND user_id = ?',
            (config_id, user_id)
        ).fetchone()
        conn.close()
        if config:
            config_dict = dict(config)
            # 解析JSON字段
            try:
                config_dict['brand_names'] = json.loads(config_dict['brand_names']) if config_dict['brand_names'] else []
                config_dict['website_domains'] = json.loads(config_dict['website_domains']) if config_dict['website_domains'] else []
                config_dict['competitors'] = json.loads(config_dict['competitors']) if config_dict['competitors'] else []
            except (json.JSONDecodeError, TypeError):
                config_dict['brand_names'] = []
                config_dict['website_domains'] = []
                config_dict['competitors'] = []
            return config_dict
        return None

    # 查询历史管理
    def create_query_task(self, user_id, task_name, prompts_file, total_prompts, api_config_id, brand_config_id):
        """创建查询任务"""
        task_id = str(uuid.uuid4())
        created_at = datetime.now().isoformat()
        
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO query_history (user_id, task_id, task_name, prompts_file, total_prompts, 
                                     api_config_id, brand_config_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, task_id, task_name, prompts_file, total_prompts, api_config_id, brand_config_id, created_at))
        
        conn.commit()
        conn.close()
        return task_id
    
    def update_query_task(self, task_id, completed_prompts=None, status=None, results_file=None, completed_at=None):
        """更新查询任务状态"""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        updates = []
        values = []
        
        if completed_prompts is not None:
            updates.append('completed_prompts = ?')
            values.append(completed_prompts)
        
        if status is not None:
            updates.append('status = ?')
            values.append(status)
        
        if results_file is not None:
            updates.append('results_file = ?')
            values.append(results_file)
        
        if completed_at is not None:
            updates.append('completed_at = ?')
            values.append(completed_at)
        
        if updates:
            values.append(task_id)
            query = f'UPDATE query_history SET {", ".join(updates)} WHERE task_id = ?'
            cursor.execute(query, values)
            conn.commit()
        
        conn.close()
    
    def get_user_query_history(self, user_id, limit=50):
        """获取用户查询历史"""
        conn = self.get_connection()
        cursor = conn.cursor()
        history = cursor.execute('''
            SELECT qh.*, ac.name as api_name, ac.endpoint
            FROM query_history qh
            LEFT JOIN api_configs ac ON qh.api_config_id = ac.id
            WHERE qh.user_id = ?
            ORDER BY qh.created_at DESC
            LIMIT ?
        ''', (user_id, limit)).fetchall()
        conn.close()
        return [dict(record) for record in history]
    
    def get_query_task(self, task_id, user_id):
        """获取特定查询任务"""
        conn = self.get_connection()
        cursor = conn.cursor()
        task = cursor.execute(
            'SELECT * FROM query_history WHERE task_id = ? AND user_id = ?',
            (task_id, user_id)
        ).fetchone()
        conn.close()
        return dict(task) if task else None


# 创建全局数据库实例
db = Database()
