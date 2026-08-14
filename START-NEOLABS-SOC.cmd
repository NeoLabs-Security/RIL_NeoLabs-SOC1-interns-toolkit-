@echo off
setlocal EnableExtensions
title NeoLabs SOC Level 1 - Start Desk

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-NeoLabsSOC.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="-ValidateOnly" exit /b %EXIT_CODE%

echo.
if not "%EXIT_CODE%"=="0" (
  echo [FAILED] NeoLabs SOC could not finish startup. Review the message above.
) else (
  echo [READY] NeoLabs SOC is running and the Wazuh dashboard has been opened.
)
echo.
pause
exit /b %EXIT_CODE%
