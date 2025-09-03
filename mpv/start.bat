@echo off
echo 正在启动 GEO Insight MVP...
echo.

REM 检查Python是否安装
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未找到Python，请先安装Python 3.7+
    pause
    exit /b 1
)

REM 检查是否存在虚拟环境
if not exist "venv" (
    echo 创建虚拟环境...
    python -m venv venv
)

REM 激活虚拟环境
echo 激活虚拟环境...
call venv\Scripts\activate

REM 安装依赖
echo 安装依赖包...
pip install -r requirements.txt

REM 启动应用
echo.
echo ================================
echo GEO Insight MVP 正在启动...
echo 请在浏览器中访问: http://localhost:5000
echo 按 Ctrl+C 停止服务器
echo ================================
echo.

python app.py
