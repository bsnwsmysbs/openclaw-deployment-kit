@echo off
setlocal
if not exist "%~dp0deployment-check\start.cmd" (
  echo Please extract the complete repository ZIP before starting.
  pause
  exit /b 1
)
call "%~dp0deployment-check\start.cmd" %*
exit /b %errorlevel%
