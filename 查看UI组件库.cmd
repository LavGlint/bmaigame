@echo off
setlocal
set "GAME_EXE=%~dp0godot-demo\outputs\windows\HanabiArena.exe"
if not exist "%GAME_EXE%" goto missing
if /I "%~1"=="--verify-start" goto verify
start "" "%GAME_EXE%" -- --screen=components
exit /b 0
:verify
if not exist "%~dp0godot-demo\outputs\qa" mkdir "%~dp0godot-demo\outputs\qa"
"%GAME_EXE%" --headless --quit-after 30 --log-file "%~dp0godot-demo\outputs\qa\component-launcher.log" -- --qa --screen=components
exit /b %ERRORLEVEL%
:missing
echo Game build not found. See godot-demo\README.md.
exit /b 1
