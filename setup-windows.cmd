@echo off
setlocal EnableExtensions
title NeoLabs SOC Windows Setup
set "NEOLABS_NO_PAUSE="
if /I "%~1"=="--no-pause" set "NEOLABS_NO_PAUSE=1"

echo NeoLabs SOC Windows / WSL2 setup
echo.

where wsl.exe >nul 2>nul
if errorlevel 1 (
  echo [MISSING] WSL2
  echo Install or enable Windows Subsystem for Linux, then install any current Linux distro.
  echo Ubuntu is NOT required; Kali, Debian and other WSL2 Linux distros are supported.
  echo A separate Ubuntu Server virtual machine is not required.
  if not defined NEOLABS_NO_PAUSE pause
  exit /b 1
)
echo [OK] WSL command detected

for /f "usebackq delims=" %%I in (`wsl.exe wslpath -a "%~dp0" 2^>nul`) do set "LINUX_ROOT=%%I"
if not defined LINUX_ROOT (
  echo [ERROR] Could not translate this toolkit path into WSL.
  echo Move or clone the toolkit into your WSL Linux filesystem and run the Linux setup there.
  if not defined NEOLABS_NO_PAUSE pause
  exit /b 1
)

echo [INFO] Toolkit path in WSL: %LINUX_ROOT%
echo [INFO] Checking Bash, Docker, Python, OpenSSL, curl, memory and kernel settings...
wsl.exe --cd "%LINUX_ROOT%" bash wazuh-stack/scripts/compatibility-check.sh
if errorlevel 1 (
  echo.
  echo [ERROR] Compatibility check reported a blocking issue.
  echo Resolve the failure shown above and run setup-windows.cmd again.
  echo If you saw a CRLF/pipefail message, pull the latest toolkit or follow docs\setup\WORKSTATION_COMPATIBILITY.md.
  if not defined NEOLABS_NO_PAUSE pause
  exit /b 1
)

wsl.exe --cd "%LINUX_ROOT%" test -f wazuh-stack/.env
if errorlevel 1 (
  echo [INFO] Preparing private local Wazuh configuration and generated secrets...
  wsl.exe --cd "%LINUX_ROOT%" bash wazuh-stack/scripts/generate-local-secrets.sh
  if errorlevel 1 (
    echo [ERROR] Could not generate the local Wazuh configuration.
    if not defined NEOLABS_NO_PAUSE pause
    exit /b 1
  )
) else (
  echo [OK] Existing wazuh-stack/.env found; it will not be overwritten.
)

echo [INFO] Running stack preparation...
wsl.exe --cd "%LINUX_ROOT%" bash wazuh-stack/scripts/prepare-stack.sh
if errorlevel 1 (
  echo [ERROR] Stack preparation failed. Review the message above before connecting.
  if not defined NEOLABS_NO_PAUSE pause
  exit /b 1
)

echo.
echo [READY] SOC workstation setup is complete.
echo Next commands:
echo   .\neolabs.cmd login
echo   .\neolabs.cmd connect
echo   .\neolabs.cmd status
echo.
if not defined NEOLABS_NO_PAUSE pause
exit /b 0
