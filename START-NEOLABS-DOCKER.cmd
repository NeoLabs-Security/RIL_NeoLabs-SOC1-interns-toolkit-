@echo off
setlocal EnableExtensions
title NeoLabs Docker Desktop / WSL2 Bootstrap

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-NeoLabsDocker.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="-ValidateOnly" exit /b %EXIT_CODE%

echo.
if not "%EXIT_CODE%"=="0" (
  echo [FAILED] Docker Desktop / WSL2 is not ready for the NeoLabs SOC workstation.
  echo Review the message above. Do not continue to Wazuh until this check passes.
) else (
  echo [READY] Docker Desktop is running with the Linux/WSL2 path required by NeoLabs SOC.
)
echo.
pause
exit /b %EXIT_CODE%
