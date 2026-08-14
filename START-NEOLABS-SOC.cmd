@echo off
setlocal EnableExtensions
title NeoLabs SOC Level 1

set "NEOLABS_START_PS1=%~dp0internal\windows\Start-NeoLabsSOC.ps1"
if not exist "%NEOLABS_START_PS1%" (
  echo [FAILED] Internal NeoLabs Windows launcher is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="-ValidateOnly" exit /b %EXIT_CODE%

echo.
if not "%EXIT_CODE%"=="0" (
  echo [FAILED] NeoLabs SOC did not complete successfully. Review the message above.
  echo For staged diagnostics run: START-NEOLABS-SOC.cmd doctor
) else (
  echo [DONE] NeoLabs SOC command completed successfully.
)
echo.
pause
exit /b %EXIT_CODE%
