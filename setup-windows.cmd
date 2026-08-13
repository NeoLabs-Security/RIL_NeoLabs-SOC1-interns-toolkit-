@echo off
setlocal
title NeoLabs Windows Readiness Check
echo NeoLabs Windows readiness check
echo.
where py >nul 2>nul
if errorlevel 1 (
  where python >nul 2>nul
  if errorlevel 1 (
    echo [MISSING] Python 3.10 or newer
    echo Install Python, then run this file again.
    pause
    exit /b 1
  )
)
echo [OK] Python detected
echo.
echo Windows prerequisites check complete.
echo.
pause
