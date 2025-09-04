#!/bin/bash

# 修复app.py中的缩进问题
echo "修复 app.py 缩进问题..."

APP_FILE="/opt/geo-insight/app/app.py"

if [ -f "$APP_FILE" ]; then
    # 备份原文件
    cp "$APP_FILE" "$APP_FILE.backup"
    
    # 修复if __name__ == '__main__'语句块的缩进
    sed -i '/^if __name__ == '\''__main__'\'':$/,/^[[:space:]]*app\.run/ {
        /^if __name__ == '\''__main__'\'':$/b
        /^[[:space:]]*#.*$/s/^[[:space:]]*/    /
        /^[[:space:]]*app\.run/s/^[[:space:]]*/    /
    }' "$APP_FILE"
    
    echo "app.py 缩进问题已修复"
    echo "原文件备份为 $APP_FILE.backup"
else
    echo "错误: 找不到文件 $APP_FILE"
    exit 1
fi
