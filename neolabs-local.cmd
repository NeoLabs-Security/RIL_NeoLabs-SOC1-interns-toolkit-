@echo off
set "NEOLABS_LAB_BASE_URL=https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0neolabs.ps1" %*
exit /b %ERRORLEVEL%
