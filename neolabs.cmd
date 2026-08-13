@echo off
setlocal
set "ROOT=%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%ROOT%tools\neolabs.py" %*
  exit /b %ERRORLEVEL%
)
where python >nul 2>nul
if not errorlevel 1 (
  python "%ROOT%tools\neolabs.py" %*
  exit /b %ERRORLEVEL%
)
echo Python 3.10 or newer is required. Install Python and try again.
exit /b 9009
