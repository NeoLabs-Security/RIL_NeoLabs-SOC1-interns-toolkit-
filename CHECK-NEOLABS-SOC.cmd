@echo off
setlocal
cd /d "%~dp0"
echo.
echo ==============================================
echo        NeoLabs SOC Level 1 - Health Check
echo ==============================================
echo.
call "%~dp0neolabs.cmd" doctor
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo NeoLabs SOC health check found one or more stages that need attention.
  echo Review the FAIL/WARN lines above before continuing the lab.
) else (
  echo NeoLabs SOC health check completed successfully.
)
echo.
pause
exit /b %RC%
