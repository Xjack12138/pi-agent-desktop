@echo off
setlocal
cd /d "%~dp0" || exit /b 1
set "PI_CODING_AGENT_DIR=%~dp0.pi-agent"
set "PI_CODING_AGENT_SESSION_DIR=%USERPROFILE%\.pi\agent\sessions"
set "CARGO_HOME=%~dp0.tools\cargo"
set "RUSTUP_HOME=%~dp0.tools\rustup"
if exist "%~dp0.tools\node\node.exe" set "PATH=%~dp0.tools\node;%PATH%"
if exist "%CARGO_HOME%\bin\cargo.exe" set "PATH=%CARGO_HOME%\bin;%PATH%"

where cargo >nul 2>nul || (
  echo Desktop dependencies are missing. Run setup-desktop.bat first.
  pause
  exit /b 1
)

title Pi Agent Desktop
call npm.cmd run desktop:dev
pause
