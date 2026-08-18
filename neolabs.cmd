@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "PS_SCRIPT=%ROOT%internal\windows\Invoke-NeoLabsCLI.ps1"

if not exist "%PS_SCRIPT%" (
  echo [FAILED] Required NeoLabs CLI adapter is missing: %PS_SCRIPT%
  exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
exit /b %ERRORLEVEL%
