#!/bin/bash

#########################################
# GEO Insight MVP - 配置脚本
# 用于配置部署脚本参数
# 支持本地和服务器端使用
#########################################

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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

# 验证域名格式
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证邮箱格式
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证IP地址格式
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 检测运行环境
detect_environment() {
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
            log_info "检测到服务器环境: $PRETTY_NAME"
            return 0
        fi
    fi
    log_info "检测到本地环境"
    return 1
}

echo "=========================================="
echo -e "${BLUE}🔧 GEO Insight MVP 部署配置向导${NC}"
echo "=========================================="
echo

# 检测运行环境
IS_SERVER=false
if detect_environment; then
    IS_SERVER=true
fi

# 检查deploy.sh是否存在
if [[ ! -f "deploy.sh" ]]; then
    log_error "未找到 deploy.sh 文件"
    log_info "请确保在包含 deploy.sh 的目录中运行此脚本"
    exit 1
fi

# 读取当前配置
CURRENT_DOMAIN=$(grep '^DOMAIN=' deploy.sh | cut -d'"' -f2)
CURRENT_EMAIL=$(grep '^EMAIL=' deploy.sh | cut -d'"' -f2)
CURRENT_USER=$(grep '^DEPLOY_USER=' deploy.sh | cut -d'"' -f2)
CURRENT_DIR=$(grep '^INSTALL_DIR=' deploy.sh | cut -d'"' -f2)
CURRENT_PORT=$(grep '^APP_PORT=' deploy.sh | cut -d'"' -f2)

echo -e "${BLUE}当前配置:${NC}"
echo "• 域名: $CURRENT_DOMAIN"
echo "• 邮箱: $CURRENT_EMAIL"
echo "• 用户: $CURRENT_USER"
echo "• 目录: $CURRENT_DIR"
echo "• 端口: $CURRENT_PORT"
echo

# 询问是否修改配置
read -p "是否要修改这些配置？(Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    log_info "保持当前配置不变"
    exit 0
fi

echo
echo -e "${YELLOW}请输入新的配置信息:${NC}"

# 获取域名
while true; do
    read -p "请输入您的域名 (例如: example.com) [$CURRENT_DOMAIN]: " DOMAIN
    DOMAIN=${DOMAIN:-$CURRENT_DOMAIN}
    
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        log_warning "建议使用真实域名以获得最佳体验"
        read -p "确认使用默认域名？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
    elif validate_domain "$DOMAIN"; then
        break
    else
        log_error "域名格式不正确，请重新输入"
    fi
done

# 获取邮箱
while true; do
    read -p "请输入您的邮箱 (用于SSL证书) [$CURRENT_EMAIL]: " EMAIL
    EMAIL=${EMAIL:-$CURRENT_EMAIL}
    
    if validate_email "$EMAIL"; then
        break
    elif [[ "$EMAIL" == "your-email@example.com" ]]; then
        log_warning "使用默认邮箱，SSL证书申请可能失败"
        break
    else
        log_error "邮箱格式不正确，请重新输入"
    fi
done

# 如果是本地环境，获取服务器IP
if [[ "$IS_SERVER" == false ]]; then
    while true; do
        read -p "请输入服务器IP地址: " SERVER_IP
        if validate_ip "$SERVER_IP"; then
            break
        else
            log_error "IP地址格式不正确，请重新输入"
        fi
    done
fi

echo
echo -e "${YELLOW}高级配置 (直接回车使用当前值):${NC}"

# 获取应用用户名
read -p "应用用户名 [$CURRENT_USER]: " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-$CURRENT_USER}

# 获取安装目录
read -p "安装目录 [$CURRENT_DIR]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$CURRENT_DIR}

# 获取应用端口
while true; do
    read -p "应用端口 [$CURRENT_PORT]: " APP_PORT
    APP_PORT=${APP_PORT:-$CURRENT_PORT}
    
    if [[ $APP_PORT =~ ^[0-9]+$ ]] && [[ $APP_PORT -ge 1024 ]] && [[ $APP_PORT -le 65535 ]]; then
        break
    else
        log_error "端口必须是1024-65535之间的数字"
    fi
done

echo
echo "=========================================="
echo -e "${BLUE}配置信息确认:${NC}"
echo "=========================================="
echo "• 域名: $DOMAIN"
echo "• 邮箱: $EMAIL"
if [[ "$IS_SERVER" == false ]]; then
    echo "• 服务器IP: $SERVER_IP"
fi
echo "• 应用用户: $DEPLOY_USER"
echo "• 安装目录: $INSTALL_DIR"
echo "• 应用端口: $APP_PORT"
echo

read -p "确认配置信息是否正确？(Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    log_info "已取消配置"
    exit 1
fi

# 备份原始部署脚本
if [[ ! -f "deploy.sh.backup" ]]; then
    log_info "备份原始部署脚本..."
    cp deploy.sh deploy.sh.backup
fi

# 更新 deploy.sh 脚本
log_info "正在更新部署脚本..."

# 使用更安全的方式更新配置
sed -i.tmp "s/^DOMAIN=\"[^\"]*\"/DOMAIN=\"$DOMAIN\"/" deploy.sh
sed -i.tmp "s/^EMAIL=\"[^\"]*\"/EMAIL=\"$EMAIL\"/" deploy.sh
sed -i.tmp "s/^DEPLOY_USER=\"[^\"]*\"/DEPLOY_USER=\"$DEPLOY_USER\"/" deploy.sh
sed -i.tmp "s|^INSTALL_DIR=\"[^\"]*\"|INSTALL_DIR=\"$INSTALL_DIR\"|" deploy.sh
sed -i.tmp "s/^APP_PORT=\"[^\"]*\"/APP_PORT=\"$APP_PORT\"/" deploy.sh

# 清理临时文件
rm -f deploy.sh.tmp

log_success "部署脚本配置完成"

# 验证配置是否成功应用
NEW_DOMAIN=$(grep '^DOMAIN=' deploy.sh | cut -d'"' -f2)
if [[ "$NEW_DOMAIN" == "$DOMAIN" ]]; then
    log_success "配置验证通过"
else
    log_error "配置可能未正确应用，请检查 deploy.sh 文件"
    exit 1
fi

# 根据环境创建不同的后续脚本
if [[ "$IS_SERVER" == false ]]; then
    # 本地环境：创建上传和部署脚本
    create_local_scripts
else
    # 服务器环境：创建管理脚本
    create_server_scripts
fi

echo
echo "=========================================="
echo -e "${GREEN}🎉 配置完成！${NC}"
echo "=========================================="

if [[ "$IS_SERVER" == false ]]; then
    show_local_next_steps
else
    show_server_next_steps
fi

# 域名解析检查
if [[ "$DOMAIN" != "your-domain.com" ]]; then
    echo
    log_info "正在验证域名解析..."
    if command -v nslookup &> /dev/null; then
        if nslookup "$DOMAIN" > /dev/null 2>&1; then
            log_success "域名解析正常"
        else
            log_warning "域名解析可能未生效，请检查DNS配置"
        fi
    else
        log_warning "无法验证域名解析（缺少nslookup命令）"
    fi
fi

# 创建本地环境脚本
create_local_scripts() {
    log_info "创建本地部署脚本..."
    
    # 创建上传脚本
    cat > upload-to-server.sh << EOF
#!/bin/bash

echo "正在上传文件到服务器..."

# 检查SSH连接
if ! ssh -o ConnectTimeout=5 root@$SERVER_IP "echo 'SSH连接正常'" 2>/dev/null; then
    echo "❌ 无法连接到服务器，请检查："
    echo "1. 服务器IP是否正确: $SERVER_IP"
    echo "2. SSH服务是否启动"
    echo "3. 防火墙是否允许SSH(22端口)"
    exit 1
fi

# 创建远程目录
ssh root@$SERVER_IP "mkdir -p /tmp/geo-insight"

# 上传所有文件
echo "正在上传项目文件..."
scp -r ./* root@$SERVER_IP:/tmp/geo-insight/ || {
    echo "❌ 文件上传失败"
    exit 1
}

echo "✅ 文件上传完成！"
echo
echo "下一步操作："
echo "1. 连接到服务器: ssh root@$SERVER_IP"
echo "2. 进入目录: cd /tmp/geo-insight"
echo "3. 运行部署: sudo bash deploy.sh"
EOF

    chmod +x upload-to-server.sh

    # 创建快捷命令脚本
    cat > deploy-commands.sh << EOF
#!/bin/bash

echo "=========================================="
echo "🚀 GEO Insight MVP 部署命令参考"
echo "=========================================="
echo
echo "📤 上传文件到服务器:"
echo "   bash upload-to-server.sh"
echo
echo "🔗 连接到服务器:"
echo "   ssh root@$SERVER_IP"
echo
echo "🚀 在服务器上运行部署:"
echo "   cd /tmp/geo-insight"
echo "   sudo bash deploy.sh"
echo
echo "📊 检查部署状态:"
echo "   sudo supervisorctl status geo-insight"
echo "   sudo systemctl status nginx"
echo
echo "📋 查看日志:"
echo "   sudo tail -f $INSTALL_DIR/logs/supervisor_error.log"
echo "   sudo tail -f /var/log/geo-insight-deploy/deploy-*.log"
echo
echo "🌐 访问应用:"
if [[ "$DOMAIN" != "your-domain.com" ]]; then
echo "   http://$DOMAIN"
echo "   https://$DOMAIN (SSL配置后)"
else
echo "   http://$SERVER_IP"
fi
echo
echo "🔧 重新配置:"
echo "   bash configure.sh"
echo
echo "=========================================="
EOF

    chmod +x deploy-commands.sh
}

# 创建服务器环境脚本
create_server_scripts() {
    log_info "创建服务器管理脚本..."
    
    # 创建管理脚本
    cat > manage.sh << EOF
#!/bin/bash

# GEO Insight MVP 服务器管理脚本

case "\$1" in
    start)
        echo "启动 GEO Insight 服务..."
        sudo supervisorctl start geo-insight
        sudo systemctl start nginx
        ;;
    stop)
        echo "停止 GEO Insight 服务..."
        sudo supervisorctl stop geo-insight
        ;;
    restart)
        echo "重启 GEO Insight 服务..."
        sudo supervisorctl restart geo-insight
        sudo systemctl reload nginx
        ;;
    status)
        echo "=== GEO Insight 服务状态 ==="
        sudo supervisorctl status geo-insight
        echo
        echo "=== Nginx 状态 ==="
        sudo systemctl status nginx --no-pager
        ;;
    logs)
        echo "=== GEO Insight 应用日志 ==="
        sudo tail -f $INSTALL_DIR/logs/supervisor_error.log
        ;;
    deploy-logs)
        echo "=== 部署日志 ==="
        sudo tail -f /var/log/geo-insight-deploy/deploy-*.log 2>/dev/null || echo "未找到部署日志"
        ;;
    backup)
        BACKUP_DIR="$INSTALL_DIR/backup/\$(date +%Y%m%d_%H%M%S)"
        echo "备份数据库到: \$BACKUP_DIR"
        sudo mkdir -p "\$BACKUP_DIR"
        sudo cp "$INSTALL_DIR/app/geo_insight.db" "\$BACKUP_DIR/"
        sudo cp -r "$INSTALL_DIR/app/uploads" "\$BACKUP_DIR/" 2>/dev/null || true
        echo "备份完成"
        ;;
    *)
        echo "GEO Insight MVP 管理脚本"
        echo "用法: \$0 {start|stop|restart|status|logs|deploy-logs|backup}"
        echo
        echo "命令说明:"
        echo "  start        - 启动服务"
        echo "  stop         - 停止服务"
        echo "  restart      - 重启服务"
        echo "  status       - 查看服务状态"
        echo "  logs         - 查看应用日志"
        echo "  deploy-logs  - 查看部署日志"
        echo "  backup       - 备份数据库和上传文件"
        ;;
esac
EOF

    chmod +x manage.sh
}

# 显示本地环境下一步操作
show_local_next_steps() {
    echo -e "${BLUE}📋 下一步操作:${NC}"
    echo "1. 上传文件: ${YELLOW}bash upload-to-server.sh${NC}"
    echo "2. 连接服务器: ${YELLOW}ssh root@$SERVER_IP${NC}"
    echo "3. 运行部署: ${YELLOW}cd /tmp/geo-insight && sudo bash deploy.sh${NC}"
    echo
    echo -e "${BLUE}📁 生成的文件:${NC}"
    echo "• deploy.sh (已更新配置)"
    echo "• upload-to-server.sh (上传脚本)"
    echo "• deploy-commands.sh (命令参考)"
    echo "• deploy.sh.backup (原始备份)"
    echo
    echo -e "${BLUE}💡 使用提示:${NC}"
    echo "• 查看命令参考: ${YELLOW}bash deploy-commands.sh${NC}"
    echo "• 重新配置: ${YELLOW}bash configure.sh${NC}"
}

# 显示服务器环境下一步操作
show_server_next_steps() {
    echo -e "${BLUE}📋 下一步操作:${NC}"
    echo "1. 运行部署: ${YELLOW}sudo bash deploy.sh${NC}"
    echo
    echo -e "${BLUE}📁 生成的文件:${NC}"
    echo "• deploy.sh (已更新配置)"
    echo "• manage.sh (服务管理脚本)"
    echo "• deploy.sh.backup (原始备份)"
    echo
    echo -e "${BLUE}💡 管理命令:${NC}"
    echo "• 查看状态: ${YELLOW}bash manage.sh status${NC}"
    echo "• 重启服务: ${YELLOW}bash manage.sh restart${NC}"
    echo "• 查看日志: ${YELLOW}bash manage.sh logs${NC}"
    echo "• 备份数据: ${YELLOW}bash manage.sh backup${NC}"
}

echo
echo -e "${YELLOW}⚠️  重要提醒:${NC}"
if [[ "$IS_SERVER" == false ]]; then
    echo "• 确保服务器防火墙允许 SSH(22)、HTTP(80)、HTTPS(443) 端口"
    echo "• 确保域名已正确解析到服务器IP: $SERVER_IP"
else
    echo "• 确保防火墙允许 HTTP(80)、HTTPS(443) 端口"
    if [[ "$DOMAIN" != "your-domain.com" ]]; then
        echo "• 确保域名已正确解析到本服务器"
    fi
fi
echo "• 部署过程中会自动配置SSL证书"
