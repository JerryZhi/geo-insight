@echo off
REM GEO Insight MVP - Windows 部署配置脚本
REM 请在 Git Bash 中运行 configure.sh 以获得更好的体验

echo ==========================================
echo    GEO Insight MVP 部署配置向导 (Windows)
echo ==========================================
echo.

echo 由于此项目需要使用Unix命令，建议使用以下方式之一：
echo.
echo 1. 使用 Git Bash (推荐):
echo    在当前目录右键选择 "Git Bash Here"
echo    然后运行: bash configure.sh
echo.
echo 2. 使用 WSL (Windows Subsystem for Linux):
echo    在 WSL 终端中运行配置脚本
echo.
echo 3. 手动配置:
echo    编辑 deploy.sh 文件，修改顶部的配置变量
echo.

set /p choice="选择方式 (1-3): "

if "%choice%"=="1" (
    echo.
    echo 正在尝试启动 Git Bash...
    start "" "C:\Program Files\Git\git-bash.exe" --cd="%CD%" -c "bash configure.sh; read -p 'Press Enter to continue...'"
) else if "%choice%"=="2" (
    echo.
    echo 请手动打开 WSL 终端并导航到此目录
    echo 然后运行: bash configure.sh
    pause
) else if "%choice%"=="3" (
    echo.
    echo 请手动编辑 deploy.sh 文件，修改以下配置:
    echo - DOMAIN="your-domain.com"     # 改为您的域名
    echo - EMAIL="your-email@example.com"  # 改为您的邮箱
    echo.
    echo 然后使用 SCP 或其他方式上传到服务器
    pause
) else (
    echo 无效选择，退出
)

echo.
echo 更多信息请查看 deployment-guide.md 文件
pause
