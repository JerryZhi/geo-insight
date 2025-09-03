#!/bin/bash

#########################################
# GEO Insight MVP - 一键部署脚本
# 适用于 Debian/Ubuntu 服务器
# 作者: GEO Insight Team
# 版本: 1.0.0
#########################################

set -e  # 遇到错误立即退出

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
    
    # 针对不同系统版本使用不同安装策略
    if [[ "$ID" == "ubuntu" ]]; then
        # Ubuntu系统
        VERSION_ID_MAJOR=$(echo "$VERSION_ID" | cut -d'.' -f1)
        if [ "$VERSION_ID_MAJOR" -ge 20 ]; then
            # Ubuntu 20.04+ 可以直接安装python3.9
            log_info "检测到Ubuntu $VERSION_ID，尝试直接安装Python 3.9..."
            apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils 2>/dev/null || {
                log_warning "直接安装失败，添加deadsnakes PPA..."
                install_python_with_ppa
            }
        else
            # 旧版Ubuntu需要PPA
            log_info "检测到旧版Ubuntu $VERSION_ID，添加deadsnakes PPA..."
            install_python_with_ppa
        fi
    elif [[ "$ID" == "debian" ]]; then
        # Debian系统
        VERSION_ID_MAJOR=$(echo "$VERSION_ID" | cut -d'.' -f1)
        if [ "$VERSION_ID_MAJOR" -ge 11 ]; then
            # Debian 11+ 可能有python3.9
            log_info "检测到Debian $VERSION_ID，尝试直接安装Python 3.9..."
            apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils 2>/dev/null || {
                log_warning "直接安装失败，使用默认Python版本..."
                install_default_python
            }
        else
            log_info "检测到旧版Debian $VERSION_ID，使用默认Python版本..."
            install_default_python
        fi
    fi
    
    # 设置默认Python版本（如果安装了3.9）
    if command -v python3.9 &> /dev/null; then
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
        log_success "Python 3.9 安装完成"
    else
        log_success "Python 安装完成"
    fi
}

# 使用PPA安装Python
install_python_with_ppa() {
    apt install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt update
    apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev python3.9-distutils
}

# 安装默认Python版本
install_default_python() {
    log_warning "安装系统默认Python版本（可能不是3.9+）"
    apt install -y python3 python3-pip python3-venv python3-dev
    
    # 检查版本是否满足要求
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 9 ]); then
        log_error "Python版本 $PYTHON_VERSION 过低，建议升级系统或手动安装Python 3.9+"
        log_error "应用可能无法正常运行"
    fi
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
    
    # 创建虚拟环境
    sudo -u $DEPLOY_USER python3 -m venv venv
    
    # 安装依赖
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"
    sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && pip install gunicorn"
    
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
from app import app
import os

if __name__ == "__main__":
    port = int(os.environ.get('PORT', $APP_PORT))
    app.run(host='127.0.0.1', port=port)
EOF
    
    # 修改app.py中的调试设置
    sed -i "s/app.run(debug=True, host='0.0.0.0', port=5000)/# Production: use gunicorn/" $INSTALL_DIR/app/app.py
    
    chown -R $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app
    log_success "生产配置创建完成"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    cd $INSTALL_DIR/app
    
    # 运行初始化脚本
    if [[ -f "setup.py" ]]; then
        sudo -u $DEPLOY_USER bash -c "source venv/bin/activate && python setup.py"
    else
        log_warning "未找到setup.py，请手动初始化数据库"
    fi
    
    # 设置权限
    chmod 644 $INSTALL_DIR/app/geo_insight.db
    chown $DEPLOY_USER:$DEPLOY_USER $INSTALL_DIR/app/geo_insight.db
    
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

# 配置Supervisor
configure_supervisor() {
    log_info "配置Supervisor..."
    
    cat > /etc/supervisor/conf.d/geo-insight.conf << EOF
[program:geo-insight]
command=$INSTALL_DIR/app/venv/bin/gunicorn -c $INSTALL_DIR/app/gunicorn.conf.py wsgi:app
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
EOF

    # 重新加载配置
    supervisorctl reread
    supervisorctl update
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
        
        # 设置自动续期
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
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
    
    # 添加到crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * $INSTALL_DIR/monitor.sh") | crontab -
    
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
    
    # 检查Nginx
    if systemctl is-active --quiet nginx; then
        log_success "Nginx 运行正常"
    else
        log_error "Nginx 未运行"
    fi
    
    # 检查Supervisor
    if systemctl is-active --quiet supervisor; then
        log_success "Supervisor 运行正常"
    else
        log_error "Supervisor 未运行"
    fi
    
    # 检查应用
    if supervisorctl status geo-insight | grep -q RUNNING; then
        log_success "GEO Insight 应用运行正常"
    else
        log_error "GEO Insight 应用未运行"
    fi
    
    # 检查端口
    if netstat -tlnp | grep -q ":$APP_PORT"; then
        log_success "应用端口 $APP_PORT 监听正常"
    else
        log_error "应用端口 $APP_PORT 未监听"
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
    echo "• 安装目录: $INSTALL_DIR"
    echo "• 应用用户: $DEPLOY_USER"
    echo "• 应用端口: $APP_PORT"
    echo
    echo -e "${BLUE}管理命令:${NC}"
    echo "• 查看应用状态: supervisorctl status geo-insight"
    echo "• 重启应用: supervisorctl restart geo-insight"
    echo "• 查看应用日志: tail -f $INSTALL_DIR/logs/supervisor_error.log"
    echo "• 查看Nginx状态: systemctl status nginx"
    echo
    echo -e "${BLUE}下一步:${NC}"
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        echo "• 修改脚本中的域名配置，然后运行SSL安装"
    else
        echo "• 访问 http://$DOMAIN 开始使用"
    fi
    echo "• 创建管理员账户"
    echo "• 配置API和品牌监测规则"
    echo
    echo -e "${YELLOW}注意: 请保存以下信息${NC}"
    echo "• SECRET_KEY: $SECRET_KEY"
    echo "• 数据库文件: $INSTALL_DIR/app/geo_insight.db"
    echo
}

# 主函数
main() {
    echo "=========================================="
    echo -e "${BLUE}🚀 GEO Insight MVP 一键部署脚本${NC}"
    echo "=========================================="
    echo
    
    # 检查配置
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        log_warning "请先修改脚本顶部的配置变量（域名、邮箱等）"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 执行部署步骤
    check_root
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
