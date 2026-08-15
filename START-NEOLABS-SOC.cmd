@echo off
setlocal EnableExtensions EnableDelayedExpansion
title NeoLabs SOC Level 1

set "NEOLABS_RUNTIME_PS1=%~dp0internal\windows\Ensure-NeoLabsRuntime.ps1"
set "NEOLABS_START_PS1=%~dp0internal\windows\Start-NeoLabsSOC.ps1"

if not exist "%NEOLABS_RUNTIME_PS1%" (
  echo [FAILED] Internal NeoLabs Windows runtime authority is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)
if not exist "%NEOLABS_START_PS1%" (
  echo [FAILED] Internal NeoLabs SOC launcher is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)

if /I "%~1"=="-ValidateOnly" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_PS1%" -ValidateOnly
  if errorlevel 1 exit /b !ERRORLEVEL!
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" -ValidateOnly
  exit /b !ERRORLEVEL!
)

echo [NeoLabs] Verifying/repairing the Windows runtime through one authoritative state machine...
powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_PS1%" -ToolkitRoot "%~dp0"
set "RUNTIME_EXIT=!ERRORLEVEL!"

if "!RUNTIME_EXIT!"=="3010" goto :restart_required
if not "!RUNTIME_EXIT!"=="0" (
  echo.
  echo [FAILED] NeoLabs could not prepare the Windows/WSL2/Docker runtime.
  echo Use the newest log under %%LOCALAPPDATA%%\NeoLabs\logs for operator review.
  echo Do not factory-reset Docker or unregister WSL.
  echo.
  pause
  exit /b !RUNTIME_EXIT!
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" %*
set "EXIT_CODE=!ERRORLEVEL!"

echo.
if not "!EXIT_CODE!"=="0" (
  echo [FAILED] NeoLabs SOC did not complete successfully. Review the stage-specific message above.
  echo For pipeline diagnostics run: START-NEOLABS-SOC.cmd doctor
) else (
  echo [DONE] NeoLabs SOC command completed successfully.
)
echo.
pause
exit /b !EXIT_CODE!

:restart_required
echo.
echo [ACTION REQUIRED] Windows enabled or updated a required WSL component.
echo Restart this PC once, then run START-NEOLABS-SOC.cmd again.
echo.
pause
exit /b 3010
