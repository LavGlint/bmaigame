@echo off
setlocal
set "GODOT_EXE=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" goto missing
if /I "%~1"=="--verify" goto verify
if /I "%~1"=="--verify-start" goto verify_start
start "" "%GODOT_EXE%" --editor --path "%~dp0."
exit /b 0
:verify
"%GODOT_EXE%" --headless --editor --path "%~dp0." --quit
exit /b %ERRORLEVEL%
:verify_start
start /wait "" "%GODOT_EXE%" --headless --editor --path "%~dp0." --quit
exit /b %ERRORLEVEL%
:missing
echo Godot editor not found: "%GODOT_EXE%"
exit /b 1
