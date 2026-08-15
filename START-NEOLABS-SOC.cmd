@echo off
setlocal EnableExtensions
title NeoLabs SOC Level 1

set "NEOLABS_REPAIR_PS1=%~dp0internal\windows\Repair-NeoLabsRuntime.ps1"
set "NEOLABS_START_PS1=%~dp0internal\windows\Start-NeoLabsSOC.ps1"

if not exist "%NEOLABS_REPAIR_PS1%" (
  echo [FAILED] Internal NeoLabs Windows AutoFix helper is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)
if not exist "%NEOLABS_START_PS1%" (
  echo [FAILED] Internal NeoLabs Windows launcher is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)

if /I "%~1"=="-ValidateOnly" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_REPAIR_PS1%" -ValidateOnly
  if errorlevel 1 exit /b %ERRORLEVEL%
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" -ValidateOnly
  exit /b %ERRORLEVEL%
)

echo [NeoLabs] Running automatic Windows/WSL2/Docker health and repair checks...
powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_REPAIR_PS1%"
set "REPAIR_EXIT=%ERRORLEVEL%"

if "%REPAIR_EXIT%"=="3010" (
  echo.
  echo [ACTION REQUIRED] Windows enabled/installed a required system component.
  echo Restart this PC once, then run START-NEOLABS-SOC.cmd again.
  echo.
  pause
  exit /b 3010
)

if not "%REPAIR_EXIT%"=="0" (
  echo.
  echo [FAILED] NeoLabs AutoFix could not safely recover this workstation automatically.
  echo Review the concise message above; a local diagnostic log is written when Docker recovery fails.
  echo.
  pause
  exit /b %REPAIR_EXIT%
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"

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
