# GEO Insight MVP - Debian 云服务器部署指南

## 📋 部署前准备

### 1. 服务器要求
- **操作系统**: Debian 10+ (推荐 Debian 11/12)
- **内存**: 最低 1GB，推荐 2GB+
- **存储**: 最低 10GB，推荐 20GB+
- **网络**: 具备公网 IP 和域名（可选）

### 2. 本地准备
- 项目代码打包
- 服务器 SSH 访问权限
- 域名配置（如需要）

## 🚀 部署步骤

### 第一步：服务器环境准备

#### 1.1 更新系统包
```bash
# 连接到服务器
ssh root@your-server-ip

# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y curl wget git vim unzip
```

#### 1.2 安装 Python 3.9+
```bash
# 检查 Python 版本
python3 --version

# 如果版本低于 3.9，安装新版本
sudo apt install -y python3.9 python3.9-pip python3.9-venv python3.9-dev

# 设置默认 Python 版本（如需要）
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
```

#### 1.3 安装 Nginx（Web 服务器）
```bash
sudo apt install -y nginx

# 启动并设置开机自启
sudo systemctl start nginx
sudo systemctl enable nginx

# 检查状态
sudo systemctl status nginx
```

#### 1.4 安装 Supervisor（进程管理）
```bash
sudo apt install -y supervisor

# 启动并设置开机自启
sudo systemctl start supervisor
sudo systemctl enable supervisor
```

### 第二步：项目部署

#### 2.1 创建项目目录和用户
```bash
# 创建专用用户
sudo adduser --system --group --home /opt/geo-insight geo-insight

# 创建项目目录
sudo mkdir -p /opt/geo-insight/app
sudo chown -R geo-insight:geo-insight /opt/geo-insight
```

#### 2.2 上传项目代码
```bash
# 方法1：使用 scp 从本地上传
# 在本地执行：
scp -r mpv/* root@your-server-ip:/tmp/geo-insight/

# 在服务器上移动文件
sudo mv /tmp/geo-insight/* /opt/geo-insight/app/
sudo chown -R geo-insight:geo-insight /opt/geo-insight/app

# 方法2：使用 git 克隆（如果代码在 Git 仓库）
cd /opt/geo-insight
sudo -u geo-insight git clone your-git-repo.git app
```

#### 2.3 安装 Python 依赖
```bash
# 切换到项目目录
cd /opt/geo-insight/app

# 创建虚拟环境
sudo -u geo-insight python3 -m venv venv

# 激活虚拟环境并安装依赖
sudo -u geo-insight bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u geo-insight bash -c "source venv/bin/activate && pip install -r requirements.txt"

# 安装额外的生产环境依赖
sudo -u geo-insight bash -c "source venv/bin/activate && pip install gunicorn"
```

#### 2.4 配置生产环境设置
```bash
# 创建生产配置文件
sudo -u geo-insight tee /opt/geo-insight/app/config.py << 'EOF'
import os

class Config:
    # 安全密钥 - 请更换为随机字符串
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'your-super-secret-key-change-this-in-production'
    
    # 数据库配置
    DATABASE_PATH = '/opt/geo-insight/app/geo_insight.db'
    
    # 文件上传配置
    UPLOAD_FOLDER = '/opt/geo-insight/app/uploads'
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB
    
    # Flask 配置
    DEBUG = False
    TESTING = False
    
    # 日志配置
    LOG_LEVEL = 'INFO'
    LOG_FILE = '/opt/geo-insight/logs/app.log'
EOF
```

#### 2.5 修改应用配置
```bash
# 创建生产版本的 app.py
sudo -u geo-insight tee /opt/geo-insight/app/wsgi.py << 'EOF'
from app import app
import os

if __name__ == "__main__":
    port = int(os.environ.get('PORT', 5000))
    app.run(host='127.0.0.1', port=port)
EOF

# 修改 app.py 中的配置
sudo -u geo-insight sed -i "s/app.run(debug=True, host='0.0.0.0', port=5000)/# Production: use gunicorn/" /opt/geo-insight/app/app.py
```

#### 2.6 初始化数据库
```bash
# 运行初始化脚本
cd /opt/geo-insight/app
sudo -u geo-insight bash -c "source venv/bin/activate && python setup.py"

# 设置正确的文件权限
sudo chown -R geo-insight:geo-insight /opt/geo-insight/app
sudo chmod -R 755 /opt/geo-insight/app
sudo chmod 644 /opt/geo-insight/app/geo_insight.db
```

### 第三步：配置 Gunicorn（WSGI 服务器）

#### 3.1 创建 Gunicorn 配置
```bash
sudo -u geo-insight tee /opt/geo-insight/app/gunicorn.conf.py << 'EOF'
import multiprocessing

# Server socket
bind = "127.0.0.1:5000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests, to help control memory leaks
max_requests = 1000
max_requests_jitter = 50

# Log files
errorlog = "/opt/geo-insight/logs/gunicorn_error.log"
accesslog = "/opt/geo-insight/logs/gunicorn_access.log"
loglevel = "info"

# Process naming
proc_name = "geo-insight"

# Server mechanics
daemon = False
pidfile = "/opt/geo-insight/gunicorn.pid"
user = "geo-insight"
group = "geo-insight"
tmp_upload_dir = None

# SSL (如果需要 HTTPS)
# keyfile = "/path/to/private.key"
# certfile = "/path/to/certificate.crt"
EOF

# 创建日志目录
sudo mkdir -p /opt/geo-insight/logs
sudo chown -R geo-insight:geo-insight /opt/geo-insight/logs
```

#### 3.2 配置 Supervisor
```bash
sudo tee /etc/supervisor/conf.d/geo-insight.conf << 'EOF'
[program:geo-insight]
command=/opt/geo-insight/app/venv/bin/gunicorn -c /opt/geo-insight/app/gunicorn.conf.py wsgi:app
directory=/opt/geo-insight/app
user=geo-insight
group=geo-insight
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stderr_logfile=/opt/geo-insight/logs/supervisor_error.log
stdout_logfile=/opt/geo-insight/logs/supervisor_out.log
environment=PATH="/opt/geo-insight/app/venv/bin",PYTHONPATH="/opt/geo-insight/app"
EOF

# 重新加载 Supervisor 配置
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start geo-insight

# 检查服务状态
sudo supervisorctl status geo-insight
```

### 第四步：配置 Nginx 反向代理

#### 4.1 创建 Nginx 站点配置
```bash
sudo tee /etc/nginx/sites-available/geo-insight << 'EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;  # 替换为您的域名

    # 限制上传文件大小
    client_max_body_size 20M;

    # 静态文件处理
    location /static {
        alias /opt/geo-insight/app/static;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # 主应用代理
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/geo-insight /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

#### 4.2 配置防火墙
```bash
# 如果使用 ufw
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 如果使用 iptables
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### 第五步：SSL/HTTPS 配置（推荐）

#### 5.1 安装 Certbot
```bash
sudo apt install -y certbot python3-certbot-nginx
```

#### 5.2 获取 SSL 证书
```bash
# 替换为您的域名和邮箱
sudo certbot --nginx -d your-domain.com -d www.your-domain.com --email your-email@example.com --agree-tos --no-eff-email

# 设置自动续期
sudo crontab -e
# 添加以下行：
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### 第六步：监控和日志

#### 6.1 设置日志轮转
```bash
sudo tee /etc/logrotate.d/geo-insight << 'EOF'
/opt/geo-insight/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 geo-insight geo-insight
    postrotate
        supervisorctl restart geo-insight
    endscript
}
EOF
```

#### 6.2 创建监控脚本
```bash
sudo tee /opt/geo-insight/monitor.sh << 'EOF'
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

sudo chmod +x /opt/geo-insight/monitor.sh

# 添加到 crontab
sudo crontab -e
# 添加以下行：
# */5 * * * * /opt/geo-insight/monitor.sh
```

## 🔧 维护命令

### 查看服务状态
```bash
# 查看应用状态
sudo supervisorctl status geo-insight

# 查看日志
sudo tail -f /opt/geo-insight/logs/gunicorn_error.log
sudo tail -f /opt/geo-insight/logs/supervisor_error.log

# 查看 Nginx 状态
sudo systemctl status nginx
```

### 重启服务
```bash
# 重启应用
sudo supervisorctl restart geo-insight

# 重启 Nginx
sudo systemctl restart nginx

# 重新加载 Nginx 配置
sudo systemctl reload nginx
```

### 更新代码
```bash
# 停止服务
sudo supervisorctl stop geo-insight

# 备份数据库
sudo -u geo-insight cp /opt/geo-insight/app/geo_insight.db /opt/geo-insight/backup/geo_insight_$(date +%Y%m%d_%H%M%S).db

# 更新代码
cd /opt/geo-insight/app
sudo -u geo-insight git pull  # 如果使用 Git
# 或者重新上传文件

# 安装新依赖（如有）
sudo -u geo-insight bash -c "source venv/bin/activate && pip install -r requirements.txt"

# 重启服务
sudo supervisorctl start geo-insight
```

## 🔒 安全建议

### 1. 系统安全
- 定期更新系统：`sudo apt update && sudo apt upgrade`
- 配置 SSH 密钥认证，禁用密码登录
- 使用非 root 用户进行日常操作
- 配置 fail2ban 防止暴力破解

### 2. 应用安全
- 更改默认的 SECRET_KEY
- 定期备份数据库
- 监控日志文件，查看异常访问
- 限制文件上传大小和类型

### 3. 网络安全
- 使用 HTTPS（已配置 SSL）
- 配置防火墙规则
- 考虑使用 CDN 服务

## 📊 性能优化

### 1. 数据库优化
```bash
# SQLite 性能调优
sudo -u geo-insight tee /opt/geo-insight/app/db_optimize.sql << 'EOF'
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = memory;
PRAGMA mmap_size = 268435456; -- 256MB
EOF

# 应用优化设置
sudo -u geo-insight bash -c "cd /opt/geo-insight/app && source venv/bin/activate && python -c \"
import sqlite3
conn = sqlite3.connect('geo_insight.db')
with open('db_optimize.sql', 'r') as f:
    conn.executescript(f.read())
conn.close()
\""
```

### 2. 系统优化
- 增加 Gunicorn worker 数量（根据 CPU 核心数）
- 配置 Redis 缓存（可选）
- 使用 SSD 存储
- 监控内存使用情况

## 🆘 故障排除

### 常见问题

**1. 应用无法启动**
```bash
# 检查日志
sudo tail -f /opt/geo-insight/logs/supervisor_error.log
sudo tail -f /opt/geo-insight/logs/gunicorn_error.log

# 检查端口占用
sudo netstat -tlnp | grep :5000

# 手动测试应用
cd /opt/geo-insight/app
sudo -u geo-insight bash -c "source venv/bin/activate && python wsgi.py"
```

**2. 数据库权限问题**
```bash
# 修复权限
sudo chown -R geo-insight:geo-insight /opt/geo-insight/app
sudo chmod 644 /opt/geo-insight/app/geo_insight.db
```

**3. Nginx 502 错误**
```bash
# 检查 Gunicorn 是否运行
sudo supervisorctl status geo-insight

# 检查 Nginx 日志
sudo tail -f /var/log/nginx/error.log
```

**4. 磁盘空间不足**
```bash
# 清理日志
sudo find /opt/geo-insight/logs -name "*.log.*" -mtime +30 -delete

# 清理旧的上传文件
sudo find /opt/geo-insight/app/uploads -mtime +90 -delete
```

## 📞 联系支持

如遇到部署问题，请检查：
1. 服务器系统版本和资源
2. 网络连接和域名配置
3. 日志文件中的错误信息
4. 防火墙和安全组设置

---

**部署完成后，您的 GEO Insight MVP 将在您的域名上正常运行！** 🎉

记住定期备份数据和监控服务状态。
