#!/bin/bash

# 快速修复脚本 - 解决当前部署问题
echo "🔧 修复当前部署问题..."

# 1. 安装cron服务
echo "[1/4] 安装cron服务..."
apt update
apt install -y cron
systemctl start cron
systemctl enable cron
echo "✅ cron服务安装完成"

# 2. 创建python软链接（如果需要）
if ! command -v python &> /dev/null; then
    echo "[2/4] 创建python软链接..."
    if command -v python3 &> /dev/null; then
        ln -sf /usr/bin/python3 /usr/bin/python
        echo "✅ python -> python3 软链接创建完成"
    else
        echo "❌ python3 未找到，请先安装Python"
    fi
else
    echo "[2/4] python命令已可用"
fi

# 3. 验证Python安装
echo "[3/4] 验证Python安装..."
python3 --version
if command -v python &> /dev/null; then
    python --version
fi

# 4. 测试应用启动
echo "[4/4] 测试应用启动..."
if [[ -f "/tmp/geo-insight/mpv/app.py" ]]; then
    cd /tmp/geo-insight/mpv
    echo "尝试启动应用（测试模式）..."
    timeout 10s python3 app.py || echo "应用启动测试完成"
else
    echo "❌ 未找到app.py文件"
fi

echo "🎉 修复完成！现在可以重新运行部署脚本"
