@echo off
setlocal
chcp 65001 >nul
set "MODE="
if /i "%~1"=="Validate" set "MODE=Validate"
if /i "%~1"=="Playground" set "MODE=Playground"
if /i "%~1"=="Gallery" set "MODE=Gallery"
if /i "%~1"=="Projectiles" set "MODE=Projectiles"
if defined MODE goto run
if not "%~1"=="" goto usage
echo.
echo 角色动画测试
echo 1. 键盘 / 手柄试玩：角色动作 + 子弹动画与测试墙
echo 2. 四方向对照预览：逐帧检查六个角色
echo 3. 自动检查：角色动画、子弹资源、键盘和手柄
echo 4. 子弹素材预览：飞行、命中、喷火、分裂等效果
echo 0. 退出
choice /c 12340 /n /m "请选择 [1/2/3/4/0]: "
if errorlevel 5 exit /b 0
if errorlevel 4 set "MODE=Projectiles"
if errorlevel 3 if not defined MODE set "MODE=Validate"
if errorlevel 2 if not defined MODE set "MODE=Gallery"
if errorlevel 1 if not defined MODE set "MODE=Playground"
:run
where pwsh.exe >nul 2>nul
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0automation\role-animations\test-animations.ps1" -Mode "%MODE%"
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0automation\role-animations\test-animations.ps1" -Mode "%MODE%"
)
set "RESULT=%ERRORLEVEL%"
if not "%~2"=="--no-pause" pause
exit /b %RESULT%
:usage
echo Usage: 测试角色动画.cmd [Validate^|Playground^|Gallery^|Projectiles] [--no-pause]
exit /b 2
