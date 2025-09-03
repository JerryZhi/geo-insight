#!/bin/bash

#########################################
# GEO Insight MVP - 本地配置脚本
# 用于配置部署脚本和准备上传
#########################################

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo -e "${BLUE}🔧 GEO Insight MVP 部署配置向导${NC}"
echo "=========================================="
echo

# 获取用户输入
read -p "请输入您的域名 (例如: example.com): " DOMAIN
read -p "请输入您的邮箱 (用于SSL证书): " EMAIL
read -p "请输入服务器IP地址: " SERVER_IP

echo
echo -e "${YELLOW}可选配置 (直接回车使用默认值):${NC}"
read -p "应用用户名 [geo-insight]: " DEPLOY_USER
read -p "安装目录 [/opt/geo-insight]: " INSTALL_DIR
read -p "应用端口 [5000]: " APP_PORT

# 设置默认值
DEPLOY_USER=${DEPLOY_USER:-geo-insight}
INSTALL_DIR=${INSTALL_DIR:-/opt/geo-insight}
APP_PORT=${APP_PORT:-5000}

echo
echo "=========================================="
echo -e "${BLUE}配置信息确认:${NC}"
echo "=========================================="
echo "域名: $DOMAIN"
echo "邮箱: $EMAIL"
echo "服务器IP: $SERVER_IP"
echo "应用用户: $DEPLOY_USER"
echo "安装目录: $INSTALL_DIR"
echo "应用端口: $APP_PORT"
echo

read -p "确认配置信息是否正确？(Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "已取消配置"
    exit 1
fi

# 更新 deploy.sh 脚本
echo -e "${BLUE}正在更新部署脚本...${NC}"

sed -i "s/DOMAIN=\"your-domain.com\"/DOMAIN=\"$DOMAIN\"/" deploy.sh
sed -i "s/EMAIL=\"your-email@example.com\"/EMAIL=\"$EMAIL\"/" deploy.sh
sed -i "s/DEPLOY_USER=\"geo-insight\"/DEPLOY_USER=\"$DEPLOY_USER\"/" deploy.sh
sed -i "s|INSTALL_DIR=\"/opt/geo-insight\"|INSTALL_DIR=\"$INSTALL_DIR\"|" deploy.sh
sed -i "s/APP_PORT=\"5000\"/APP_PORT=\"$APP_PORT\"/" deploy.sh

echo -e "${GREEN}✅ 部署脚本配置完成${NC}"

# 创建上传脚本
echo -e "${BLUE}正在创建上传脚本...${NC}"

cat > upload-to-server.sh << EOF
#!/bin/bash

echo "正在上传文件到服务器..."

# 创建临时目录
ssh root@$SERVER_IP "mkdir -p /tmp/geo-insight"

# 上传所有文件
scp -r ./* root@$SERVER_IP:/tmp/geo-insight/

echo "文件上传完成！"
echo "现在可以连接到服务器运行部署脚本："
echo "ssh root@$SERVER_IP"
echo "cd /tmp/geo-insight"
echo "chmod +x deploy.sh"
echo "sudo bash deploy.sh"
EOF

chmod +x upload-to-server.sh

echo -e "${GREEN}✅ 上传脚本创建完成${NC}"

# 创建快捷命令脚本
cat > deploy-commands.sh << EOF
#!/bin/bash

# GEO Insight MVP 部署快捷命令

echo "=========================================="
echo "🚀 GEO Insight MVP 部署命令"
echo "=========================================="
echo

echo "1. 上传文件到服务器:"
echo "   bash upload-to-server.sh"
echo

echo "2. 连接到服务器:"
echo "   ssh root@$SERVER_IP"
echo

echo "3. 在服务器上运行部署:"
echo "   cd /tmp/geo-insight"
echo "   chmod +x deploy.sh"
echo "   sudo bash deploy.sh"
echo

echo "4. 检查部署状态:"
echo "   sudo supervisorctl status geo-insight"
echo "   sudo systemctl status nginx"
echo

echo "5. 查看日志:"
echo "   sudo tail -f $INSTALL_DIR/logs/supervisor_error.log"
echo

echo "6. 访问应用:"
echo "   http://$DOMAIN"
echo "   https://$DOMAIN (SSL配置后)"
echo

echo "=========================================="
EOF

chmod +x deploy-commands.sh

echo
echo "=========================================="
echo -e "${GREEN}🎉 配置完成！${NC}"
echo "=========================================="
echo
echo -e "${BLUE}下一步操作:${NC}"
echo "1. 运行上传脚本: ${YELLOW}bash upload-to-server.sh${NC}"
echo "2. 连接服务器: ${YELLOW}ssh root@$SERVER_IP${NC}"
echo "3. 运行部署: ${YELLOW}cd /tmp/geo-insight && sudo bash deploy.sh${NC}"
echo
echo -e "${BLUE}常用命令:${NC}"
echo "• 查看部署命令: ${YELLOW}bash deploy-commands.sh${NC}"
echo "• 重新配置: ${YELLOW}bash configure.sh${NC}"
echo
echo -e "${BLUE}生成的文件:${NC}"
echo "• deploy.sh (已更新配置)"
echo "• upload-to-server.sh (上传脚本)"
echo "• deploy-commands.sh (命令参考)"
echo

# 验证DNS解析
echo -e "${BLUE}正在验证DNS解析...${NC}"
if nslookup $DOMAIN > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 域名解析正常${NC}"
else
    echo -e "${YELLOW}⚠️  域名解析可能未生效，请检查DNS配置${NC}"
fi

echo
echo -e "${YELLOW}⚠️  重要提醒:${NC}"
echo "• 确保服务器防火墙允许 SSH(22)、HTTP(80)、HTTPS(443) 端口"
echo "• 确保域名已正确解析到服务器IP: $SERVER_IP"
echo "• 部署过程中会自动配置SSL证书"
echo
