@echo off
setlocal EnableExtensions
title NeoLabs Docker Desktop + WSL2 Setup

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-DockerWSL2.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="-ValidateOnly" exit /b %EXIT_CODE%

echo.
if not "%EXIT_CODE%"=="0" (
  echo [FAILED] Docker Desktop / WSL2 setup did not complete. Review the message above.
) else (
  echo [READY] Docker Desktop is running and accessible from the default WSL2 distribution.
)
echo.
pause
exit /b %EXIT_CODE%
