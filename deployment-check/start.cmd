@echo off
setlocal
cd /d "%~dp0"
set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not exist "%PWSH_EXE%" set "PWSH_EXE=pwsh.exe"
"%PWSH_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" %*
if errorlevel 1 pause
