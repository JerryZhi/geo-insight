# GEO Insight MVP - 宝塔面板部署指南

## 🎨 宝塔面板可视化部署

宝塔面板是一个功能强大的服务器管理工具，提供图形化界面，让部署和管理变得简单直观。适合不熟悉命令行操作的用户。

## 📋 部署前准备

### 1. 服务器要求
- **操作系统**: Debian 10+ / Ubuntu 18.04+ / CentOS 7+
- **内存**: 最低 1GB，推荐 2GB+ (宝塔面板本身需要约 200MB)
- **存储**: 最低 20GB，推荐 40GB+
- **网络**: 具备公网 IP
- **端口**: 确保 8888(宝塔)、80、443、22 端口开放

### 2. 域名准备
- ✅ **已购买域名**: 如 `your-domain.com`
- ✅ **DNS 解析配置**: A 记录指向服务器 IP
  ```
  A    @              your-server-ip
  A    www            your-server-ip
  A    geo            your-server-ip  (可选子域名)
  ```

### 3. 必要信息
- ✅ **服务器 IP 地址**
- ✅ **服务器 root 密码**
- ✅ **域名**
- ✅ **邮箱地址** (用于 SSL 证书)

## 🚀 第一步：安装宝塔面板

### 1.1 连接服务器
```bash
# 使用 SSH 连接服务器
ssh root@your-server-ip
```

### 1.2 安装宝塔面板

#### Debian/Ubuntu 系统
```bash
wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh
```

#### CentOS 系统
```bash
yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
```

### 1.3 记录安装信息
安装完成后，会显示重要信息：
```
==================================================================
恭喜! 安装宝塔成功!
==================================================================
外网面板地址: http://your-server-ip:8888/
内网面板地址: http://127.0.0.1:8888/
username: bt_username
password: bt_password
security code: bt_security_code
==================================================================
```

**⚠️ 重要：请保存这些信息！**

## 🎛️ 第二步：配置宝塔面板

### 2.1 登录宝塔面板
1. 打开浏览器，访问：`http://your-server-ip:8888`
2. 输入用户名和密码
3. 输入安全码

### 2.2 安装推荐软件
首次登录会弹出推荐安装界面，选择以下组件：

#### 必需软件
- ✅ **Nginx 1.20+** (Web 服务器)
- ✅ **Python 项目管理器** (Python 环境管理)
- ✅ **Supervisor 管理器** (进程管理)

#### 可选软件
- ⭕ **MySQL** (如果需要数据库升级)
- ⭕ **Redis** (如果需要缓存)
- ⭕ **phpMyAdmin** (不需要，我们用 SQLite)

点击 **"一键安装"** 等待安装完成（约 10-15 分钟）

### 2.3 安全设置
在 **面板设置** 中：
1. 修改面板端口（建议改为非默认端口）
2. 绑定域名或 IP 白名单
3. 开启面板 SSL（可选）

## 🐍 第三步：配置 Python 环境

### 3.1 安装 Python 项目管理器
1. 进入 **软件商店**
2. 找到 **"Python 项目管理器"**
3. 点击 **安装**

### 3.2 安装 Python 版本
1. 点击 **软件商店** → **Python 项目管理器** → **设置**
2. 在 **版本管理** 中安装 **Python 3.9** 或更高版本
3. 等待安装完成

### 3.3 创建项目
1. 在 **Python 项目管理器** 中点击 **添加项目**
2. 填写项目信息：
   ```
   项目名称: geo-insight
   路径: /www/wwwroot/geo-insight
   Python版本: 3.9.7
   框架: 其他
   启动方式: gunicorn
   端口: 5000
   ```
3. 点击 **提交**

## 📁 第四步：上传项目文件

### 4.1 方法一：通过面板上传
1. 进入 **文件管理**
2. 导航到 `/www/wwwroot/geo-insight`
3. 点击 **上传** 按钮
4. 上传项目文件（支持拖拽上传）

### 4.2 方法二：通过命令行上传
```bash
# 在本地执行（Windows 用户在 Git Bash 中执行）
scp -r mpv/* root@your-server-ip:/www/wwwroot/geo-insight/
```

### 4.3 设置文件权限
在 **文件管理** 中：
1. 选择项目根目录
2. 右键 → **权限** → 设置为 **755**
3. 勾选 **应用到子目录**

## ⚙️ 第五步：配置项目依赖

### 5.1 安装 Python 依赖
1. 进入 **Python 项目管理器**
2. 找到 `geo-insight` 项目，点击 **设置**
3. 在 **依赖模块** 标签页：
   ```
   添加以下模块：
   - Flask==2.3.3
   - pandas==2.2.3
   - aiohttp==3.12.15
   - gunicorn==21.2.0
   - 或者点击 "从文件安装" 选择 requirements.txt
   ```

### 5.2 配置启动参数
在项目设置的 **启动参数** 中：
```
启动文件: app.py
框架: 其他
启动方式: gunicorn
启动参数: --bind 127.0.0.1:5000 --workers 3 --timeout 30
```

### 5.3 创建启动脚本
在 **文件管理** 中创建 `start.py`：
```python
# /www/wwwroot/geo-insight/start.py
from app import app

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
```

## 🌐 第六步：配置网站和域名

### 6.1 添加网站
1. 进入 **网站** 管理
2. 点击 **添加站点**
3. 填写信息：
   ```
   域名: your-domain.com
   根目录: /www/wwwroot/geo-insight
   FTP: 不创建
   数据库: 不创建
   PHP版本: 纯静态
   ```

### 6.2 配置反向代理
1. 点击网站右侧的 **设置**
2. 进入 **反向代理** 标签页
3. 点击 **添加反向代理**：
   ```
   代理名称: geo-insight
   目标URL: http://127.0.0.1:5000
   发送域名: $host
   ```
4. 点击 **保存**

### 6.3 配置 URL 重写（可选）
在 **URL重写** 标签页添加：
```nginx
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

location /static {
    alias /www/wwwroot/geo-insight/static;
    expires 30d;
}
```

## 🔒 第七步：配置 SSL 证书

### 7.1 申请免费 SSL 证书
1. 在网站设置中点击 **SSL** 标签页
2. 选择 **Let's Encrypt** 免费证书
3. 填写邮箱地址
4. 选择域名（勾选 `your-domain.com` 和 `www.your-domain.com`）
5. 点击 **申请**

### 7.2 强制 HTTPS
证书申请成功后：
1. 开启 **强制HTTPS**
2. 开启 **HSTS**（可选）

## 🔄 第八步：配置进程管理

### 8.1 安装 Supervisor 管理器
1. 进入 **软件商店**
2. 找到 **Supervisor 管理器**
3. 点击 **安装**

### 8.2 添加守护进程
1. 打开 **Supervisor 管理器**
2. 点击 **添加守护进程**
3. 填写配置：
   ```
   名称: geo-insight
   启动用户: www
   运行目录: /www/wwwroot/geo-insight
   启动命令: /www/server/python_manager/versions/3.9.7/bin/gunicorn -c gunicorn.conf.py app:app
   进程数量: 1
   ```

### 8.3 创建 Gunicorn 配置文件
在文件管理中创建 `/www/wwwroot/geo-insight/gunicorn.conf.py`：
```python
import multiprocessing

# 绑定地址和端口
bind = "127.0.0.1:5000"

# 工作进程数
workers = multiprocessing.cpu_count() * 2 + 1

# 工作模式
worker_class = "sync"

# 超时时间
timeout = 30

# 日志配置
accesslog = "/www/wwwroot/geo-insight/logs/access.log"
errorlog = "/www/wwwroot/geo-insight/logs/error.log"
loglevel = "info"

# 进程名称
proc_name = "geo-insight"
```

## 🗄️ 第九步：数据库初始化

### 9.1 通过终端初始化
1. 进入 **终端** 工具
2. 执行以下命令：
   ```bash
   cd /www/wwwroot/geo-insight
   /www/server/python_manager/versions/3.9.7/bin/python setup.py
   ```

### 9.2 设置数据库权限
```bash
chown www:www geo_insight.db
chmod 644 geo_insight.db
```

## 📊 第十步：监控和维护

### 10.1 系统监控
宝塔面板提供丰富的监控功能：
- **系统状态**: CPU、内存、磁盘使用情况
- **网站监控**: 访问统计、错误日志
- **进程监控**: Python 进程运行状态

### 10.2 日志管理
1. **网站日志**: 在网站设置 → **日志** 中查看
2. **Python 日志**: 在 `/www/wwwroot/geo-insight/logs/` 目录
3. **系统日志**: 在面板首页查看系统信息

### 10.3 自动备份设置
1. 进入 **计划任务**
2. 添加 **备份网站** 任务
3. 设置定期备份（建议每日备份）

## 🔧 常用管理操作

### 网站管理
```bash
# 通过面板操作
1. 重启网站: 网站列表 → 停止/启动
2. 重载配置: Nginx设置 → 重载配置
3. 查看日志: 网站设置 → 日志
```

### 进程管理
```bash
# 通过 Supervisor 管理器
1. 启动进程: 点击 "启动"
2. 停止进程: 点击 "停止"  
3. 重启进程: 点击 "重启"
4. 查看日志: 点击 "日志"
```

### 文件管理
- **在线编辑**: 双击文件进行在线编辑
- **权限管理**: 右键文件 → 权限
- **压缩解压**: 右键 → 压缩/解压
- **上传下载**: 拖拽上传，右键下载

## ⚡ 性能优化建议

### 10.1 Nginx 优化
在网站设置 → **配置文件** 中优化：
```nginx
# 开启 gzip 压缩
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# 设置缓存
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 10.2 Python 应用优化
- **增加 Worker 数量**: 根据 CPU 核心数调整
- **启用 Gunicorn 预加载**: 减少内存使用
- **配置连接池**: 优化数据库连接

## 🆘 故障排除

### 常见问题解决

#### 1. 网站无法访问
```bash
检查步骤:
1. 网站是否启动 (网站列表查看状态)
2. 域名解析是否正确 (ping 域名)
3. 防火墙端口是否开放 (安全 → 防火墙)
4. Nginx 配置是否正确 (配置文件语法检查)
```

#### 2. Python 应用启动失败
```bash
检查步骤:
1. 查看 Supervisor 进程状态
2. 检查 Python 依赖是否安装完整
3. 查看错误日志 (/www/wwwroot/geo-insight/logs/)
4. 检查文件权限 (www:www)
```

#### 3. SSL 证书申请失败
```bash
检查步骤:
1. 域名解析是否生效
2. 80 端口是否被占用
3. 域名是否已被其他证书使用
4. 防火墙是否允许 80/443 端口
```

#### 4. 数据库权限问题
```bash
解决方法:
1. 检查数据库文件权限: ls -la geo_insight.db
2. 修复权限: chown www:www geo_insight.db
3. 检查目录权限: chmod 755 /www/wwwroot/geo-insight
```

## 🎯 部署后验证

### 验证步骤
1. **访问测试**: 打开 `https://your-domain.com`
2. **功能测试**: 注册账户、上传文件、运行分析
3. **性能测试**: 查看响应时间和资源使用
4. **安全检测**: SSL 评级、安全头检查

### 检查清单
- ✅ 网站可以正常访问
- ✅ HTTPS 证书有效
- ✅ 用户注册登录功能正常
- ✅ 文件上传功能正常
- ✅ API 配置功能正常
- ✅ 分析任务可以运行
- ✅ 数据库读写正常
- ✅ 日志记录正常

## 📱 宝塔手机APP管理

### 安装手机APP
1. 下载 **宝塔手机版** APP
2. 添加服务器（扫码或手动输入）
3. 随时随地管理服务器

### 手机端功能
- 📊 **实时监控**: 查看服务器状态
- 🔄 **服务管理**: 重启服务、查看日志
- 📁 **文件管理**: 上传下载文件
- ⚠️ **告警通知**: 异常情况推送通知

## 🎉 部署完成

恭喜！您已经成功通过宝塔面板部署了 GEO Insight MVP。

### 🌟 宝塔面板的优势
- **可视化管理**: 所有操作都有图形界面
- **一键操作**: SSL证书、备份、监控等一键完成
- **移动管理**: 手机APP随时管理
- **安全防护**: 内置防火墙、入侵检测
- **性能监控**: 实时查看系统状态
- **定时任务**: 自动备份、日志清理等

### 📞 技术支持
- **宝塔官方文档**: https://www.bt.cn/bbs/
- **项目问题**: 查看项目 README 和部署文档
- **紧急问题**: 通过面板的在线工具诊断

---

**🎊 部署成功！您的 GEO Insight MVP 现在可以通过 https://your-domain.com 访问了！**

记住定期通过宝塔面板进行维护和监控。
