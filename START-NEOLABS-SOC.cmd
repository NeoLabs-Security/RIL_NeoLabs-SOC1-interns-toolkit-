@echo off
setlocal EnableExtensions EnableDelayedExpansion
title NeoLabs SOC Level 1

set "NEOLABS_REPAIR_PS1=%~dp0internal\windows\Repair-NeoLabsRuntime.ps1"
set "NEOLABS_RUNTIME_TEST_PS1=%~dp0internal\windows\Test-NeoLabsDockerRuntime.ps1"
set "NEOLABS_BACKEND_RECOVERY_PS1=%~dp0internal\windows\Recover-DockerDesktopBackend.ps1"
set "NEOLABS_START_PS1=%~dp0internal\windows\Start-NeoLabsSOC.ps1"

if not exist "%NEOLABS_REPAIR_PS1%" (
  echo [FAILED] Internal NeoLabs Windows AutoFix helper is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)
if not exist "%NEOLABS_RUNTIME_TEST_PS1%" (
  echo [FAILED] Internal NeoLabs Windows runtime confirmation helper is missing.
  echo Pull the latest toolkit and try again.
  pause
  exit /b 1
)
if not exist "%NEOLABS_BACKEND_RECOVERY_PS1%" (
  echo [FAILED] Internal NeoLabs Docker backend recovery helper is missing.
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
  if errorlevel 1 exit /b !ERRORLEVEL!
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_TEST_PS1%" -ValidateOnly
  if errorlevel 1 exit /b !ERRORLEVEL!
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_BACKEND_RECOVERY_PS1%" -ValidateOnly
  if errorlevel 1 exit /b !ERRORLEVEL!
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" -ValidateOnly
  exit /b !ERRORLEVEL!
)

echo [NeoLabs] Checking whether the existing Windows/WSL2/Docker runtime is already healthy...
powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_TEST_PS1%"
set "RUNTIME_TEST_EXIT=!ERRORLEVEL!"

if "!RUNTIME_TEST_EXIT!"=="0" (
  echo [NeoLabs] Existing Docker Linux runtime is healthy. Skipping unnecessary repair/restart work.
  set "REPAIR_EXIT=0"
) else (
  echo [NeoLabs] Running automatic Windows/WSL2/Docker health and repair checks...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_REPAIR_PS1%"
  set "REPAIR_EXIT=!ERRORLEVEL!"
)

if "!REPAIR_EXIT!"=="3010" goto :restart_required

if not "!REPAIR_EXIT!"=="0" (
  echo.
  echo [NeoLabs] Primary AutoFix reported Docker unavailable. Confirming the real Linux engine before recycling anything...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_TEST_PS1%"
  set "RUNTIME_TEST_EXIT=!ERRORLEVEL!"

  if "!RUNTIME_TEST_EXIT!"=="0" (
    echo [NeoLabs] Docker is actually healthy on Windows and inside WSL2. Ignoring the stale AutoFix failure and continuing safely.
    set "REPAIR_EXIT=0"
  ) else (
    echo [NeoLabs] Docker readiness could not be confirmed. Trying one deeper non-destructive Docker Desktop backend/service recycle...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_BACKEND_RECOVERY_PS1%"
    set "BACKEND_EXIT=!ERRORLEVEL!"

    if "!BACKEND_EXIT!"=="0" (
      echo [NeoLabs] Docker backend recovery returned successfully. Verifying the actual runtime before another repair pass...
      powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_TEST_PS1%"
      set "RUNTIME_TEST_EXIT=!ERRORLEVEL!"

      if "!RUNTIME_TEST_EXIT!"=="0" (
        set "REPAIR_EXIT=0"
      ) else (
        echo [NeoLabs] Re-running the complete Windows readiness check for any remaining WSL integration repair...
        powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_REPAIR_PS1%"
        set "REPAIR_EXIT=!ERRORLEVEL!"

        if not "!REPAIR_EXIT!"=="0" if not "!REPAIR_EXIT!"=="3010" (
          echo [NeoLabs] Final confirmation: checking whether Docker became healthy despite the AutoFix return code...
          powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_RUNTIME_TEST_PS1%"
          if "!ERRORLEVEL!"=="0" set "REPAIR_EXIT=0"
        )
      )
    )
  )
)

if "!REPAIR_EXIT!"=="3010" goto :restart_required

if not "!REPAIR_EXIT!"=="0" (
  echo.
  echo [FAILED] NeoLabs AutoFix could not safely recover this workstation automatically.
  echo Review the concise message above. NeoLabs wrote local diagnostic logs for both the normal and deeper Docker recovery paths when available.
  echo.
  pause
  exit /b !REPAIR_EXIT!
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%NEOLABS_START_PS1%" %*
set "EXIT_CODE=!ERRORLEVEL!"

echo.
if not "!EXIT_CODE!"=="0" (
  echo [FAILED] NeoLabs SOC did not complete successfully. Review the message above.
  echo For staged diagnostics run: START-NEOLABS-SOC.cmd doctor
) else (
  echo [DONE] NeoLabs SOC command completed successfully.
)
echo.
pause
exit /b !EXIT_CODE!

:restart_required
echo.
echo [ACTION REQUIRED] Windows enabled/installed a required system component.
echo Restart this PC once, then run START-NEOLABS-SOC.cmd again.
echo.
pause
exit /b 3010
