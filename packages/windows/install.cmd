@echo off
setlocal
cd /d "%~dp0"
set "PWSH_EXE="

if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PWSH_EXE (
  for /f "delims=" %%P in ('where pwsh.exe 2^>nul') do (
    if not defined PWSH_EXE set "PWSH_EXE=%%P"
  )
)

if not defined PWSH_EXE (
  echo [ERROR] PowerShell 7 pwsh.exe is required.
  echo [ERROR] Windows PowerShell 5.1 powershell.exe is not supported by this installer.
  echo [INFO]  Please install PowerShell 7, then run install.cmd again.
  echo [INFO]  Expected path: C:\Program Files\PowerShell\7\pwsh.exe
  pause
  exit /b 1
)

"%PWSH_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
pause
exit /b %EXIT_CODE%
