@echo off
setlocal
set "GAME_EXE=%~dp0outputs\windows\HanabiArena.exe"
if exist "%GAME_EXE%" goto game_ready
set "GODOT_EXE=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" goto editor_fallback
echo Neither the demo build nor the local Godot editor was found.
pause
exit /b 1
:editor_fallback
start "" "%GODOT_EXE%" --editor --path "%~dp0."
exit /b 0
:game_ready
if /I "%~1"=="--verify-start" goto verify_game
start "" "%GAME_EXE%"
exit /b 0
:verify_game
if not exist "%~dp0outputs\qa" mkdir "%~dp0outputs\qa"
set "QA_LOG=%~dp0outputs\qa\launcher-game.log"
set "QA_IMAGE=%~dp0outputs\qa\launcher-play.png"
start /wait "" "%GAME_EXE%" --position -3000,-3000 --resolution 1440x1024 --log-file "%QA_LOG%" -- --qa --demo --capture="%QA_IMAGE%"
exit /b %ERRORLEVEL%
