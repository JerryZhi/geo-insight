#!/bin/bash

# 直接修复app.py中的缩进问题
echo "正在修复 /opt/geo-insight/app/app.py 的缩进问题..."

APP_FILE="/opt/geo-insight/app/app.py"

if [ ! -f "$APP_FILE" ]; then
    echo "错误: 找不到文件 $APP_FILE"
    exit 1
fi

# 备份原文件
cp "$APP_FILE" "$APP_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# 创建临时文件来修复问题
TEMP_FILE=$(mktemp)

# 读取文件并修复最后几行的缩进
python3 << 'EOF'
import sys

app_file = "/opt/geo-insight/app/app.py"
temp_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/app_fixed.py"

with open(app_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复最后几行
fixed_lines = []
in_main_block = False

for i, line in enumerate(lines):
    # 检测if __name__ == '__main__':行
    if line.strip().startswith("if __name__ == '__main__':"):
        in_main_block = True
        fixed_lines.append(line)
        continue
    
    # 如果在main块中，确保正确缩进
    if in_main_block:
        # 如果遇到没有缩进的非空行，main块结束
        if line.strip() and not line.startswith(' ') and not line.startswith('\t'):
            in_main_block = False
            fixed_lines.append(line)
            continue
        
        # 如果是空行，直接添加
        if not line.strip():
            fixed_lines.append(line)
            continue
            
        # 确保注释和代码行有正确的缩进（4个空格）
        if line.strip().startswith('#') or line.strip().startswith('app.run'):
            fixed_lines.append('    ' + line.lstrip())
        else:
            fixed_lines.append(line)
    else:
        fixed_lines.append(line)

# 写入临时文件
with open(temp_file, 'w', encoding='utf-8') as f:
    f.writelines(fixed_lines)

print(f"修复完成，结果写入: {temp_file}")
EOF $TEMP_FILE

# 替换原文件
if [ -f "$TEMP_FILE" ]; then
    cp "$TEMP_FILE" "$APP_FILE"
    rm "$TEMP_FILE"
    echo "app.py 缩进问题已修复"
    echo "原文件已备份"
    
    # 验证修复
    echo "验证语法..."
    cd /opt/geo-insight/app
    if python3 -m py_compile app.py; then
        echo "✅ 语法检查通过"
    else
        echo "❌ 语法检查失败，恢复备份"
        cp "$APP_FILE.backup.$(date +%Y%m%d_%H%M%S)" "$APP_FILE"
        exit 1
    fi
else
    echo "修复失败"
    exit 1
fi

echo "修复完成！"
