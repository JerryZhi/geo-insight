#!/bin/bash

#########################################
# GEO Insight MV# 更新系统包
## ...existing code...
# 适用于 Debian/Ubuntu 服务器
# 作者: GEO Insight Team
# 版本: 1.0.0
#########################################

set -e  # 遇到错误立即退出

# 创建日志目录
LOG_DIR="/var/log/geo-insight-deploy"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

# 重定向输出到日志文件
exec 1> >(tee -a $LOG_FILE)
exec 2> >(tee -a $LOG_FILE >&2)

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行发生错误，退出码: $exit_code"
    log_error "详细日志已保存到: $LOG_FILE"
    log_info "请检查日志文件并联系技术支持"
    exit $exit_code
}

# 设置错误陷阱
trap 'handle_error $LINENO' ERR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量 - 请在部署前修改这些值
DOMAIN="your-domain.com"                    # 您的域名
EMAIL="your-email@example.com"              # 用于SSL证书的邮箱
SECRET_KEY="$(openssl rand -base64 32)"      # 自动生成的安全密钥
DEPLOY_USER="geo-insight"                    # 应用运行用户
INSTALL_DIR="/opt/geo-insight"              # 安装目录
APP_PORT="5000"                             # 应用端口

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash deploy.sh"
        exit 1
    fi
}

# 预检查系统环境
pre_check() {
    log_info "执行部署前预检查..."
    
    # 检查网络连接
    log_info "检查网络连接..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "网络连接正常"
    else
        log_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    # 检查磁盘空间 (至少需要2GB)
    log_info "检查磁盘空间..."
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=2097152  # 2GB in KB
    if [ "$AVAILABLE_SPACE" -gt "$REQUIRED_SPACE" ]; then
        log_success "磁盘空间充足 ($(($AVAILABLE_SPACE/1024/1024))GB 可用)"
    else
        log_error "磁盘空间不足，至少需要2GB可用空间"
        exit 1
    fi
    
    # 检查内存
    log_info "检查内存..."
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [ "$TOTAL_MEM" -gt 512 ]; then
        log_success "内存充足 (${TOTAL_MEM}MB)"
    else
        log_warning "内存较少 (${TOTAL_MEM}MB)，建议至少1GB"
    fi
    
    # 检查必要端口是否被占用
    log_info "检查端口占用情况..."
    for port in 80 443 5000; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用"
            netstat -tlnp | grep ":$port "
        else
            log_success "端口 $port 可用"
        fi
    done
    
    # 检查当前目录是否包含应用文件
    if [[ ! -f "app.py" ]]; then
        log_error "未在当前目录找到app.py文件"
        log_info "请确保在包含应用代码的目录中运行此脚本"
        log_info "当前目录内容:"
        ls -la
        exit 1
    fi
    
    log_success "预检查完成，系统满足部署条件"
}

# 检查系统版本
check_system() {
    log_info "检查系统版本..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法确定系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
        log_error "此脚本仅支持 Debian/Ubuntu 系统"
        exit 1
    fi
    
    log_success "系统检查通过: $PRETTY_NAME"
}

# 更新系统包
update_system() {
    log_info "更新系统包..."
    apt update && apt upgrade -y
    apt install -y curl wget git vim unzip software-properties-common build-essential
    log_success "系统包更新完成"
}

# 安装Python 3.9+
install_python() {
    log_info "安装Python环境..."
    
    # 检查Python版本
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        # 使用原生bash比较，避免依赖bc
        MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
        MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
        if [ "$MAJOR" -gt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -ge 9 ]); then
            log_success "Python $PYTHON_VERSION 已安装，满足要求"
            # 确保pip可用
            if ! command -v pip3 &> /dev/null; then
                log_info "安装pip..."
                apt install -y python3-pip
            fi
            return
        fi
    fi
    
    # 获取系统信息
    source /etc/os-release
    log_info "检测到系统: $PRETTY_NAME"
    
    # 根据系统版本选择最佳安装策略
    if [[ "$ID" == "debian" ]]; then
        install_python_debian
    elif [[ "$ID" == "ubuntu" ]]; then
        install_python_ubuntu
    else
        log_error "不支持的系统类型: $ID"
        exit 1
    fi
    
    # 验证Python安装
    verify_python_installation
    
    # 创建python软链接（可选）
    if ! command -v python &> /dev/null && command -v python3 &> /dev/null; then
        log_info "创建python软链接..."
        ln -sf /usr/bin/python3 /usr/bin/python
    fi
    
    log_success "Python环境安装完成"
}

# Debian系统Python安装
install_python_debian() {
    VERSION_ID_MAJOR=$(echo "$VERSION_ID" | cut -d'.' -f1)
    
    if [ "$VERSION_ID_MAJOR" -ge 11 ]; then
        # Debian 11+ 尝试安装Python 3.9+
        log_info "Debian $VERSION_ID 尝试安装Python 3.9..."
        
        # 更新包列表
        apt update
        
        # 尝试安装Python 3.9
        if apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils 2>/dev/null; then
            log_success "Python 3.9 安装成功"
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
        else
            log_warning "Python 3.9 不可用，安装默认版本..."
            install_default_python
        fi
    else
        # 旧版Debian
        log_info "旧版Debian $VERSION_ID，安装默认Python版本..."
        install_default_python
    fi
}

# Ubuntu系统Python安装
install_python_ubuntu() {
    VERSION_ID_MAJOR=$(echo "$VERSION_ID" | cut -d'.' -f1)
    
    if [ "$VERSION_ID_MAJOR" -ge 20 ]; then
        # Ubuntu 20.04+ 直接安装
        log_info "Ubuntu $VERSION_ID 直接安装Python 3.9..."
        apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils || {
            log_warning "直接安装失败，使用PPA..."
            install_python_with_ppa
        }
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
    else
        # 旧版Ubuntu使用PPA
        log_info "旧版Ubuntu $VERSION_ID，使用deadsnakes PPA..."
        install_python_with_ppa
    fi
}

# 使用PPA安装Python
install_python_with_ppa() {
    log_info "添加deadsnakes PPA..."
    apt install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt update
    
    # 安装Python 3.9
    apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils
    
    # 设置为默认Python3版本
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
}

# 安装默认Python版本
install_default_python() {
    log_warning "安装系统默认Python版本"
    
    # 安装Python基础包
    apt install -y python3 python3-pip python3-venv python3-dev python3-setuptools
    
    # 检查版本
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    log_info "已安装Python版本: $PYTHON_VERSION"
    
    # 检查版本是否满足最低要求
    MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 8 ]); then
        log_error "Python版本 $PYTHON_VERSION 过低 (需要3.8+)"
        log_error "建议升级系统或手动安装新版Python"
        exit 1
    fi
}

# 验证Python安装
verify_python_installation() {
    log_info "验证Python安装..."
    
    # 检查python3命令
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 安装失败"
        exit 1
    fi
    
    # 检查pip3命令
    if ! command -v pip3 &> /dev/null; then
        log_warning "pip3 不可用，尝试安装..."
        
        # 尝试安装pip
        if command -v python3.9 &> /dev/null; then
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9
        else
            apt install -y python3-pip
        fi
    fi
    
    # 验证pip可用性
    if command -v pip3 &> /dev/null; then
        log_success "pip3 可用: $(pip3 --version)"
    else
        log_error "pip3 安装失败"
        exit 1
    fi
    
    # 升级pip
    log_info "升级pip..."
    python3 -m pip install --upgrade pip
}

# 安装Nginx
install_nginx() {
    log_info "安装Nginx..."
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    log_success "Nginx安装完成"
}

# 安装Supervisor
install_supervisor() {
    log_info "安装Supervisor..."
    apt install -y supervisor
    systemctl start supervisor
    systemctl enable supervisor
    log_success "Supervisor安装完成"
}

# 创建应用用户和目录
create_user_and_dirs() {
    log_info "创建应用用户和目录..."
    
    # 创建用户
    if ! id "$DEPLOY_USER" &>/dev/null; then
        adduser --system --group --home $INSTALL_DIR $DEPLOY_USER
        log_success "用户 $DEPLOY_USER 创建完成"
    else
        log_warning "用户 $DEPLOY_USER 已存在"
    fi
    
    # 创建目录
    mkdir -p $INSTALL_DIR/{app,logs,backup}
    chown -R $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR
    log_success "目录结构创建完成"
}

# 部署应用代码
deploy_app() {
    log_info "部署应用代码..."
    
    # 检查当前目录是否包含应用文件
    if [[ ! -f "app.py" ]]; then
        log_error "未找到应用文件。请确保在包含app.py的目录中运行此脚本"
        log_info "或者将应用代码复制到 $INSTALL_DIR/app/"
        exit 1
    fi
    
    # 复制文件
    cp -r ./* $INSTALL_DIR/app/
    chown -R $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app
    
    log_success "应用代码部署完成"
}

# 安装Python依赖
install_python_deps() {
    log_info "安装Python依赖..."
    
    cd $INSTALL_DIR/app
    
    # 创建虚拟环境，使用更稳健的方法
    log_info "创建Python虚拟环境..."
    sudo -u $DEPLOY_USER python3 -m venv venv
    
    # 确保虚拟环境创建成功
    if [[ ! -f "$INSTALL_DIR/app/venv/bin/activate" ]]; then
        log_error "虚拟环境创建失败"
        exit 1
    fi
    
    # 升级pip和安装基础工具
    log_info "升级pip和安装基础工具..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -m pip install --upgrade pip setuptools wheel"
    
    # 安装依赖，使用超时和重试机制
    log_info "安装项目依赖..."
    if [[ -f "requirements.txt" ]]; then
        # 尝试安装依赖，如果失败则使用镜像源
        sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install -r requirements.txt --timeout 300" || {
            log_warning "使用默认源安装失败，尝试使用清华镜像源..."
            sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple/ --timeout 300"
        }
    else
        log_error "未找到requirements.txt文件"
        exit 1
    fi
    
    # 安装gunicorn
    log_info "安装gunicorn..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install gunicorn"
    
    # 验证关键包是否安装成功
    log_info "验证依赖安装..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'import flask; print(f\"Flask版本: {flask.__version__}\")'"
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'import gunicorn; print(f\"Gunicorn版本: {gunicorn.__version__}\")'"
    
    log_success "Python依赖安装完成"
}

# 创建生产配置
create_config() {
    log_info "创建生产配置..."
    
    # 创建配置文件
    cat > $INSTALL_DIR/app/config.py << EOF
import os

class Config:
    # 安全密钥
    SECRET_KEY = '$SECRET_KEY'
    
    # 数据库配置
    DATABASE_PATH = '$INSTALL_DIR/app/geo_insight.db'
    
    # 文件上传配置
    UPLOAD_FOLDER = '$INSTALL_DIR/app/uploads'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB
    
    # Flask 配置
    DEBUG = False
    TESTING = False
    
    # 日志配置
    LOG_LEVEL = 'INFO'
    LOG_FILE = '$INSTALL_DIR/logs/app.log'
EOF

    # 创建WSGI入口
    cat > $INSTALL_DIR/app/wsgi.py << EOF
#!/usr/bin/env python3
import sys
import os

# 添加应用目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from app import app
    print("Flask app imported successfully")
except ImportError as e:
    print(f"Failed to import Flask app: {e}")
    sys.exit(1)

# 确保应用对象可用
application = app

if __name__ == "__main__":
    port = int(os.environ.get('PORT', $APP_PORT))
    app.run(host='127.0.0.1', port=port)
EOF
    
    # 修改app.py中的调试设置，避免缩进错误
    log_info "修复app.py中的生产环境配置..."
    
    # 更安全的替换方式，保持正确的缩进
    if grep -q "app.run(debug=True" $INSTALL_DIR/app/app.py; then
        # 创建临时文件进行替换
        python3 << 'EOF'
import re

# 读取文件
with open('/opt/geo-insight/app/app.py', 'r') as f:
    content = f.read()

# 查找并替换app.run行，保持正确缩进
pattern = r'(\s*)app\.run\(debug=True.*?\)'
replacement = r'\1# Production: use gunicorn instead\n\1# app.run(debug=True, host="0.0.0.0", port=5000)'

new_content = re.sub(pattern, replacement, content)

# 写入文件
with open('/opt/geo-insight/app/app.py', 'w') as f:
    f.write(new_content)

print("app.py 修复完成")
EOF
    else
        log_warning "未找到需要替换的app.run语句"
    fi
    
    chown -R $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app
    log_success "生产配置创建完成"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    cd $INSTALL_DIR/app
    
    # 检查setup.py文件
    if [[ -f "setup.py" ]]; then
        log_info "运行数据库初始化脚本..."
        sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python setup.py" || {
            log_error "数据库初始化失败，请检查setup.py脚本"
            log_info "尝试手动初始化..."
            
            # 尝试直接创建数据库
            sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c \"
import sqlite3
import os
db_path = 'geo_insight.db'
if not os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    print('数据库文件已创建')
    conn.close()
else:
    print('数据库文件已存在')
\""
        }
    else
        log_warning "未找到setup.py，手动创建数据库文件..."
        sudo -u $DEPLOY_USER touch geo_insight.db
    fi
    
    # 确保数据库文件存在
    if [[ ! -f "$INSTALL_DIR/app/geo_insight.db" ]]; then
        log_warning "数据库文件不存在，创建空数据库..."
        sudo -u $DEPLOY_USER touch $INSTALL_DIR/app/geo_insight.db
    fi
    
    # 设置数据库文件权限
    chmod 644 $INSTALL_DIR/app/geo_insight.db
    chown $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app/geo_insight.db
    
    # 验证数据库文件
    if [[ -f "$INSTALL_DIR/app/geo_insight.db" ]]; then
        log_success "数据库文件创建成功: $(ls -la $INSTALL_DIR/app/geo_insight.db)"
    else
        log_error "数据库文件创建失败"
        exit 1
    fi
    
    log_success "数据库初始化完成"
}

# 配置Gunicorn
configure_gunicorn() {
    log_info "配置Gunicorn..."
    
    cat > $INSTALL_DIR/app/gunicorn.conf.py << EOF
import multiprocessing

# Server socket
bind = "127.0.0.1:$APP_PORT"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests
max_requests = 1000
max_requests_jitter = 50

# Log files
errorlog = "$INSTALL_DIR/logs/gunicorn_error.log"
accesslog = "$INSTALL_DIR/logs/gunicorn_access.log"
loglevel = "info"

# Process naming
proc_name = "geo-insight"

# Server mechanics
daemon = False
pidfile = "$INSTALL_DIR/gunicorn.pid"
user = "$DEPLOY_USER"
group = "$DEPLOY_USER"
tmp_upload_dir = None
EOF

    chown $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app/gunicorn.conf.py
    log_success "Gunicorn配置完成"
}

# 诊断应用问题
diagnose_app() {
    log_info "诊断应用问题..."
    
    cd $INSTALL_DIR/app
    
    # 检查 Python 模块导入
    log_info "测试 Python 模块导入..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'import sys; print(\"Python path:\", sys.path)'"
    
    # 测试 Flask 应用导入
    log_info "测试 Flask 应用导入..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'from app import app; print(\"Flask app imported successfully\")'" || {
        log_error "Flask 应用导入失败"
        return 1
    }
    
    # 测试 WSGI 模块
    log_info "测试 WSGI 模块..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'import wsgi; print(\"WSGI module imported successfully\")'" || {
        log_error "WSGI 模块导入失败"
        return 1
    }
    
    # 测试数据库连接
    log_info "测试数据库连接..."
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c 'import sqlite3; conn = sqlite3.connect(\"geo_insight.db\"); print(\"Database connection successful\"); conn.close()'" || {
        log_error "数据库连接失败"
        return 1
    }
    
    # 检查文件权限
    log_info "检查文件权限..."
    ls -la $INSTALL_DIR/app/ | head -10
    
    log_success "应用诊断完成"
}

# 配置Supervisor
configure_supervisor() {
    log_info "配置Supervisor..."
    
    cat > /etc/supervisor/conf.d/geo-insight.conf << EOF
[program:geo-insight]
command=$INSTALL_DIR/app/venv/bin/gunicorn -c $INSTALL_DIR/app/gunicorn.conf.py wsgi:application
directory=$INSTALL_DIR/app
user=$DEPLOY_USER
group=$DEPLOY_USER
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stderr_logfile=$INSTALL_DIR/logs/supervisor_error.log
stdout_logfile=$INSTALL_DIR/logs/supervisor_out.log
environment=PATH="$INSTALL_DIR/app/venv/bin",PYTHONPATH="$INSTALL_DIR/app"
redirect_stderr=true
stdout_logfile_maxbytes=50MB
stderr_logfile_maxbytes=50MB
startsecs=10
startretries=3
EOF

    # 重新加载配置
    supervisorctl reread
    supervisorctl update
    
    # 首先停止可能存在的进程
    supervisorctl stop geo-insight 2>/dev/null || true
    
    # 等待一下再启动
    sleep 2
    
    # 启动服务
    supervisorctl start geo-insight
    
    log_success "Supervisor配置完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    cat > /etc/nginx/sites-available/geo-insight << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # 限制上传文件大小
    client_max_body_size 20M;

    # 静态文件处理
    location /static {
        alias $INSTALL_DIR/app/static;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # 主应用代理
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/geo-insight /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    nginx -t
    systemctl reload nginx
    
    log_success "Nginx配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查是否安装了ufw
    if command -v ufw &> /dev/null; then
        ufw allow ssh
        ufw allow 'Nginx Full'
        ufw --force enable
        log_success "UFW防火墙配置完成"
    else
        log_warning "未检测到UFW，请手动配置防火墙"
    fi
}

# 安装SSL证书
install_ssl() {
    log_info "安装SSL证书..."
    
    # 安装certbot
    apt install -y certbot python3-certbot-nginx
    
    # 获取证书
    if [[ "$DOMAIN" != "your-domain.com" ]]; then
        certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --no-eff-email --non-interactive
        
        # 设置自动续期（检查crontab是否可用）
        if command -v crontab &> /dev/null; then
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            log_success "SSL证书自动续期已设置"
        else
            log_warning "crontab不可用，请手动设置SSL证书续期"
            log_info "手动设置命令: echo '0 12 * * * /usr/bin/certbot renew --quiet' | crontab -"
        fi
        
        log_success "SSL证书安装完成"
    else
        log_warning "请修改脚本中的域名配置后重新运行SSL安装"
    fi
}

# 创建监控脚本
create_monitoring() {
    log_info "创建监控脚本..."
    
    cat > $INSTALL_DIR/monitor.sh << 'EOF'
#!/bin/bash

# 检查应用状态
APP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [ $APP_STATUS -ne 200 ]; then
    echo "$(date): Application unhealthy, restarting..." >> /opt/geo-insight/logs/monitor.log
    supervisorctl restart geo-insight
fi

# 检查磁盘空间
DISK_USAGE=$(df /opt/geo-insight | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$(date): Disk usage high: ${DISK_USAGE}%" >> /opt/geo-insight/logs/monitor.log
fi
EOF

    chmod +x $INSTALL_DIR/monitor.sh
    
    # 添加到crontab（检查crontab是否可用）
    if command -v crontab &> /dev/null; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * $INSTALL_DIR/monitor.sh") | crontab -
        log_success "监控脚本已添加到crontab"
    else
        log_warning "crontab不可用，请手动添加监控任务"
        log_info "手动添加命令: echo '*/5 * * * * $INSTALL_DIR/monitor.sh' | crontab -"
    fi
    
    log_success "监控脚本创建完成"
}

# 设置日志轮转
setup_logrotate() {
    log_info "设置日志轮转..."
    
    cat > /etc/logrotate.d/geo-insight << EOF
$INSTALL_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $DEPLOY_USER $DEPLOY_USER
    postrotate
        supervisorctl restart geo-insight
    endscript
}
EOF

    log_success "日志轮转配置完成"
}

# 优化数据库
optimize_database() {
    log_info "优化数据库..."
    
    cat > $INSTALL_DIR/app/db_optimize.sql << 'EOF'
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = memory;
PRAGMA mmap_size = 268435456;
EOF

    cd $INSTALL_DIR/app
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python -c \"
import sqlite3
conn = sqlite3.connect('geo_insight.db')
with open('db_optimize.sql', 'r') as f:
    conn.executescript(f.read())
conn.close()
\""

    log_success "数据库优化完成"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    # 等待服务启动
    sleep 5
    
    # 检查Nginx
    if systemctl is-active --quiet nginx; then
        log_success "Nginx 运行正常"
    else
        log_error "Nginx 未运行"
        systemctl status nginx --no-pager -l
    fi
    
    # 检查Supervisor
    if systemctl is-active --quiet supervisor; then
        log_success "Supervisor 运行正常"
    else
        log_error "Supervisor 未运行"
        systemctl status supervisor --no-pager -l
    fi
    
    # 检查应用进程
    if supervisorctl status geo-insight | grep -q RUNNING; then
        log_success "GEO Insight 应用运行正常"
    else
        log_error "GEO Insight 应用未运行"
        log_info "应用状态:"
        supervisorctl status geo-insight
        log_info "应用日志:"
        tail -20 $INSTALL_DIR/logs/supervisor_error.log 2>/dev/null || echo "日志文件不存在"
    fi
    
    # 检查端口监听
    if netstat -tlnp | grep -q ":$APP_PORT"; then
        log_success "应用端口 $APP_PORT 监听正常"
    else
        log_error "应用端口 $APP_PORT 未监听"
        log_info "当前监听的端口:"
        netstat -tlnp | grep LISTEN
    fi
    
    # 检查应用响应
    log_info "测试应用响应..."
    sleep 2
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$APP_PORT/ | grep -q "200\|302\|404"; then
        log_success "应用响应正常"
    else
        log_warning "应用可能未正常响应，请检查日志"
    fi
    
    # 检查健康检查端点
    if curl -s http://localhost/health 2>/dev/null | grep -q "healthy"; then
        log_success "健康检查端点正常"
    else
        log_warning "健康检查端点未响应"
    fi
}

# 显示部署信息
show_deployment_info() {
    echo
    echo "=========================================="
    echo -e "${GREEN}🎉 GEO Insight MVP 部署完成！${NC}"
    echo "=========================================="
    echo
    echo -e "${BLUE}部署信息:${NC}"
    echo "• 应用地址: http://$DOMAIN"
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        echo "• 本地访问: http://$(hostname -I | awk '{print $1}')"
    fi
    echo "• 安装目录: $INSTALL_DIR"
    echo "• 应用用户: $DEPLOY_USER"
    echo "• 应用端口: $APP_PORT"
    echo "• 部署日志: $LOG_FILE"
    echo
    echo -e "${BLUE}系统信息:${NC}"
    echo "• 操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "• Python版本: $(python3 --version)"
    echo "• 数据库: SQLite ($INSTALL_DIR/app/geo_insight.db)"
    echo
    echo -e "${BLUE}管理命令:${NC}"
    echo "• 查看应用状态: supervisorctl status geo-insight"
    echo "• 重启应用: supervisorctl restart geo-insight"
    echo "• 查看应用日志: tail -f $INSTALL_DIR/logs/supervisor_error.log"
    echo "• 查看Nginx状态: systemctl status nginx"
    echo "• 查看部署日志: tail -f $LOG_FILE"
    echo
    echo -e "${BLUE}文件位置:${NC}"
    echo "• 应用代码: $INSTALL_DIR/app/"
    echo "• 配置文件: $INSTALL_DIR/app/config.py"
    echo "• Nginx配置: /etc/nginx/sites-available/geo-insight"
    echo "• Supervisor配置: /etc/supervisor/conf.d/geo-insight.conf"
    echo
    echo -e "${BLUE}下一步:${NC}"
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        echo "• 修改脚本中的域名配置，然后运行SSL安装"
        echo "• 或直接访问 http://$(hostname -I | awk '{print $1}') 开始使用"
    else
        echo "• 访问 http://$DOMAIN 开始使用"
    fi
    echo "• 创建管理员账户"
    echo "• 配置API和品牌监测规则"
    echo "• 定期备份数据库文件"
    echo
    echo -e "${YELLOW}重要信息 (请保存):${NC}"
    echo "• SECRET_KEY: $SECRET_KEY"
    echo "• 数据库文件: $INSTALL_DIR/app/geo_insight.db"
    echo "• 部署日志: $LOG_FILE"
    echo
    echo -e "${GREEN}部署成功！应用已启动并运行。${NC}"
    echo
}

# 主函数
main() {
    echo "=========================================="
    echo -e "${BLUE}🚀 GEO Insight MVP 一键部署脚本${NC}"
    echo "=========================================="
    echo
    
    # 检查是否可以使用配置脚本
    if [[ -f "configure.sh" && "$DOMAIN" == "your-domain.com" ]]; then
        echo -e "${YELLOW}检测到未配置的默认设置${NC}"
        echo -e "${BLUE}建议使用配置脚本来设置域名和邮箱${NC}"
        echo
        read -p "是否运行配置脚本？(Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            log_info "运行配置脚本..."
            bash configure.sh
            if [[ $? -eq 0 ]]; then
                log_success "配置完成，重新启动部署脚本..."
                exec bash deploy.sh
            else
                log_error "配置失败，继续使用默认配置"
            fi
        fi
    fi
    
    # 检查配置
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        log_warning "使用默认域名配置，建议修改脚本中的配置变量"
        echo -e "${BLUE}配置选项:${NC}"
        echo "1. 手动编辑 deploy.sh 修改 DOMAIN 和 EMAIL 变量"
        if [[ -f "configure.sh" ]]; then
            echo "2. 运行 'bash configure.sh' 使用配置向导"
        fi
        echo "3. 继续使用默认配置（仅支持IP访问）"
        echo
        read -p "选择操作 (1-3) 或直接回车继续: " -n 1 -r
        echo
        
        case $REPLY in
            1)
                log_info "请编辑 deploy.sh 文件，修改顶部的配置变量"
                exit 0
                ;;
            2)
                if [[ -f "configure.sh" ]]; then
                    bash configure.sh && exec bash deploy.sh
                else
                    log_error "configure.sh 文件不存在"
                fi
                ;;
            3|"")
                log_warning "继续使用默认配置..."
                ;;
            *)
                log_error "无效选择"
                exit 1
                ;;
        esac
    fi
    
    # 显示当前配置
    echo -e "${BLUE}当前部署配置:${NC}"
    echo "• 域名: $DOMAIN"
    echo "• 邮箱: $EMAIL"
    echo "• 应用用户: $DEPLOY_USER"
    echo "• 安装目录: $INSTALL_DIR"
    echo "• 应用端口: $APP_PORT"
    echo
    
    read -p "确认配置无误，继续部署？(Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    # 执行部署步骤
    check_root
    pre_check
    check_system
    update_system
    install_python
    install_nginx
    install_supervisor
    create_user_and_dirs
    deploy_app
    install_python_deps
    create_config
    init_database
    configure_gunicorn
    
    # 诊断应用问题
    diagnose_app
    
    configure_supervisor
    configure_nginx
    configure_firewall
    create_monitoring
    setup_logrotate
    optimize_database
    
    # SSL证书安装（可选）
    read -p "是否安装SSL证书？(Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        install_ssl
    fi
    
    # 检查服务状态
    check_services
    
    # 显示部署信息
    show_deployment_info
}

# 运行主函数
main "$@"
