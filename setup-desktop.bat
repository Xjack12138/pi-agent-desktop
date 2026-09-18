@echo off
setlocal
cd /d "%~dp0" || exit /b 1
title Pi Agent Desktop Setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-desktop.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed. Review the error above.
  pause
  exit /b 1
)
echo.
echo Setup complete. Run start-desktop.bat to open Pi Agent.
pause
