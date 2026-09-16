@echo off
setlocal
title GNOSIS

set "GODOT=C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"

REM Pasta deste .bat, SEM a barra final (a barra quebrava as aspas antes)
set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"

if not exist "%GODOT%" (
  echo [ERRO] Nao encontrei o Godot em:
  echo   %GODOT%
  echo Abra o Godot uma vez pelo menu Iniciar pra confirmar a versao/caminho.
  echo.
  pause
  exit /b 1
)

if not exist "%PROJ%\project.godot" (
  echo [ERRO] Nao encontrei project.godot em:
  echo   %PROJ%
  echo Este .bat precisa ficar DENTRO da pasta do jogo (Gnosis).
  echo.
  pause
  exit /b 1
)

echo Abrindo GNOSIS...
"%GODOT%" --path "%PROJ%"

echo.
echo (Jogo fechado. Codigo de saida: %ERRORLEVEL%)
pause
