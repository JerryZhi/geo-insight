# GEO Insight MVP - 部署前准备清单

## 🚀 一键部署脚本使用指南

### 📋 部署前准备（必须完成）

#### 1. 服务器准备
- ✅ **云服务器**: 已购买并配置 Debian 10+ 或 Ubuntu 18.04+ 服务器
- ✅ **规格要求**: 
  - 内存: 最低 1GB，推荐 2GB+
  - 存储: 最低 10GB，推荐 20GB+
  - CPU: 1核心以上
- ✅ **网络**: 服务器具备公网 IP
- ✅ **SSH 访问**: 可以通过 SSH 连接到服务器
- ✅ **Root 权限**: 确保有 sudo 或 root 权限

#### 2. 域名配置（推荐）
- ✅ **域名**: 已购买域名（如：example.com）
- ✅ **DNS 解析**: 将域名 A 记录指向服务器公网 IP
  ```
  A    @              your-server-ip
  A    www            your-server-ip
  ```
- ✅ **域名生效**: 确认域名解析已生效
  ```bash
  # 本地测试
  nslookup your-domain.com
  ping your-domain.com
  ```

#### 3. 邮箱准备（SSL 证书用）
- ✅ **有效邮箱**: 用于申请 Let's Encrypt SSL 证书

### 🔧 部署步骤

#### 第一步：修改配置
1. **编辑 deploy.sh 脚本**，修改顶部的配置变量：
   ```bash
   # 在脚本顶部修改这些值
   DOMAIN="your-domain.com"                    # 改为您的域名
   EMAIL="your-email@example.com"              # 改为您的邮箱
   # 其他配置保持默认即可
   ```

#### 第二步：上传文件
1. **方法一：使用 scp 上传**
   ```bash
   # 在本地执行（Windows 用户在 Git Bash 中执行）
   scp -r mpv/* root@your-server-ip:/tmp/geo-insight/
   ```

2. **方法二：使用 Git 仓库**
   ```bash
   # 先将代码推送到 Git 仓库，然后在服务器上克隆
   git clone https://your-repo.git /tmp/geo-insight
   ```

#### 第三步：运行部署脚本
```bash
# 连接到服务器
ssh root@your-server-ip

# 进入代码目录
cd /tmp/geo-insight

# 给脚本执行权限
chmod +x deploy.sh

# 运行部署脚本
sudo bash deploy.sh
```

### 📝 配置说明

#### 默认配置
```bash
# 应用配置
DEPLOY_USER="geo-insight"                    # 应用运行用户
INSTALL_DIR="/opt/geo-insight"              # 安装目录
APP_PORT="5000"                             # 应用端口

# 安全配置
SECRET_KEY="$(openssl rand -base64 32)"      # 自动生成安全密钥
```

#### 可选修改的配置
如果需要，您可以修改这些配置：
- `DEPLOY_USER`: 应用运行用户名
- `INSTALL_DIR`: 安装目录路径
- `APP_PORT`: 应用端口（默认5000，nginx会代理到80/443）

### 🔍 脚本功能详解

#### 自动化安装的组件
1. **系统环境**
   - 更新系统包
   - 安装 Python 3.9+
   - 安装必要的工具

2. **Web 服务**
   - Nginx (反向代理)
   - Gunicorn (WSGI服务器)
   - Supervisor (进程管理)

3. **应用部署**
   - 创建专用用户和目录
   - 安装 Python 依赖
   - 配置生产环境
   - 初始化数据库

4. **安全配置**
   - 防火墙设置
   - SSL 证书申请
   - 文件权限配置

5. **监控维护**
   - 健康检查脚本
   - 日志轮转配置
   - 自动重启机制

### ⚠️ 注意事项

#### 必须注意的事项
1. **备份现有数据**: 如果服务器上有其他网站，请先备份
2. **端口冲突**: 确保端口 80、443、5000 未被占用
3. **域名解析**: 确保域名已正确解析到服务器 IP
4. **网络安全**: 确保服务器安全组/防火墙允许 HTTP(80) 和 HTTPS(443) 访问

#### 可能遇到的问题
1. **权限问题**: 确保使用 root 或有 sudo 权限的用户
2. **网络问题**: 确保服务器可以访问外网（下载软件包）
3. **域名问题**: 如果域名未配置，可以先使用 IP 访问，后续再配置域名

### 🚀 部署后验证

#### 检查服务状态
```bash
# 检查应用状态
sudo supervisorctl status geo-insight

# 检查 Nginx 状态
sudo systemctl status nginx

# 检查端口监听
sudo netstat -tlnp | grep :5000
sudo netstat -tlnp | grep :80
```

#### 访问测试
```bash
# 本地测试
curl http://localhost/health

# 远程测试
curl http://your-domain.com/health
```

### 📚 部署后操作

#### 1. 首次访问
- 访问 `http://your-domain.com` 或 `https://your-domain.com`
- 注册管理员账户
- 配置 API 设置

#### 2. 常用管理命令
```bash
# 查看应用日志
sudo tail -f /opt/geo-insight/logs/supervisor_error.log

# 重启应用
sudo supervisorctl restart geo-insight

# 重启 Nginx
sudo systemctl restart nginx

# 查看数据库
sudo -u geo-insight sqlite3 /opt/geo-insight/app/geo_insight.db
```

#### 3. 更新应用
```bash
# 停止应用
sudo supervisorctl stop geo-insight

# 备份数据库
sudo cp /opt/geo-insight/app/geo_insight.db /opt/geo-insight/backup/

# 更新代码（根据您的方式）
# 重启应用
sudo supervisorctl start geo-insight
```

### 🆘 故障排除

#### 常见问题及解决方案

1. **脚本执行失败**
   ```bash
   # 查看详细错误信息
   bash -x deploy.sh
   ```

2. **应用无法启动**
   ```bash
   # 查看错误日志
   sudo tail -f /opt/geo-insight/logs/supervisor_error.log
   ```

3. **无法访问网站**
   ```bash
   # 检查防火墙
   sudo ufw status
   
   # 检查 Nginx 配置
   sudo nginx -t
   ```

4. **SSL 证书问题**
   ```bash
   # 手动申请证书
   sudo certbot --nginx -d your-domain.com
   ```

### 📞 技术支持

如果遇到问题，请提供以下信息：
1. 服务器系统版本：`cat /etc/os-release`
2. 错误日志内容
3. 具体的错误步骤
4. 服务器配置信息

---

**准备好以上内容后，就可以开始一键部署了！** 🎉
