#!/bin/bash
# 一键修复geo-insight app.py缩进问题的脚本
# 请在服务器上直接运行此脚本

echo "=========================================="
echo "🔧 geo-insight app.py 缩进问题一键修复"
echo "=========================================="

# 1. 拉取最新代码
echo "📥 拉取最新代码..."
cd /tmp/geo-insight
git pull origin master
echo "✅ 代码更新完成"

# 2. 备份当前app.py
echo "💾 备份当前app.py..."
sudo cp /opt/geo-insight/app/app.py /opt/geo-insight/app/app.py.backup.$(date +%Y%m%d_%H%M%S)

# 3. 直接修复缩进问题
echo "🔧 修复缩进问题..."
sudo tee /tmp/fix_app.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import re

app_file = "/opt/geo-insight/app/app.py"

with open(app_file, 'r', encoding='utf-8') as f:
    content = f.read()

# 修复if __name__ == '__main__': 块的缩进
# 查找并替换问题的缩进
fixed_content = re.sub(
    r"(if __name__ == '__main__':\s*\n)(.*?)(\n*$)",
    lambda m: m.group(1) + re.sub(r'^[ \t]*', '    ', m.group(2), flags=re.MULTILINE) + m.group(3),
    content,
    flags=re.DOTALL
)

# 特殊处理注释行和app.run行，确保它们有正确的缩进
lines = fixed_content.split('\n')
fixed_lines = []
in_main_block = False

for line in lines:
    if "if __name__ == '__main__':" in line:
        in_main_block = True
        fixed_lines.append(line)
    elif in_main_block and line.strip() and not line.startswith(' ') and not line.startswith('\t'):
        # 遇到非缩进的非空行，main块结束
        in_main_block = False
        fixed_lines.append(line)
    elif in_main_block and line.strip():
        # 在main块中，确保有4个空格的缩进
        if line.strip().startswith('#') or 'app.run' in line:
            fixed_lines.append('    ' + line.lstrip())
        else:
            fixed_lines.append(line)
    else:
        fixed_lines.append(line)

# 写回文件
with open(app_file, 'w', encoding='utf-8') as f:
    f.write('\n'.join(fixed_lines))

print("✅ app.py 缩进修复完成")
EOF

sudo python3 /tmp/fix_app.py

# 4. 验证语法
echo "🔍 验证语法..."
cd /opt/geo-insight/app
if sudo python3 -c "import app; print('✅ app.py语法正确')"; then
    echo "✅ 语法验证通过"
else
    echo "❌ 语法验证失败，恢复备份..."
    sudo cp /opt/geo-insight/app/app.py.backup.* /opt/geo-insight/app/app.py
    exit 1
fi

# 5. 重新启动服务
echo "🔄 重新启动geo-insight服务..."
sudo systemctl restart geo-insight
sleep 3

# 6. 检查服务状态
echo "📊 检查服务状态..."
if sudo systemctl is-active --quiet geo-insight; then
    echo "✅ geo-insight服务运行正常"
    sudo systemctl status geo-insight --no-pager -l
else
    echo "❌ geo-insight服务启动失败"
    echo "查看错误日志:"
    sudo journalctl -u geo-insight --no-pager -l -n 20
fi

echo "=========================================="
echo "🎉 修复完成！"
echo "如果服务仍有问题，请检查日志:"
echo "sudo journalctl -u geo-insight -f"
echo "=========================================="
