@echo off
rem Abre o jogo a partir desta pasta. Use "play.bat web" para ver o renderer da web (Compatibility).
rem Se a Godot estiver em outro lugar, defina GODOT com o caminho do executavel.
setlocal
cd /d "%~dp0"
if not defined GODOT set "GODOT=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
    echo Godot nao encontrada em "%GODOT%".
    echo Defina a variavel GODOT com o caminho do executavel da Godot 4.7.2.
    pause
    exit /b 1
)
if not exist ".godot\imported" "%GODOT%" --headless --path . --import
if /i "%~1"=="web" (
    start "" "%GODOT%" --path . --rendering-method gl_compatibility
) else (
    start "" "%GODOT%" --path .
)
