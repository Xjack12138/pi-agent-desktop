@echo off
setlocal
cd /d "%~dp0" || exit /b 1
set "PI_CODING_AGENT_DIR=%~dp0.pi-agent"
set "PI_CODING_AGENT_SESSION_DIR=%USERPROFILE%\.pi\agent\sessions"
title Pi Web
echo Starting Pi Web. Keep this window open; press Ctrl+C to stop.
powershell.exe -NoProfile -Command "$opened = $false; & npm.cmd run dev 2>&1 | ForEach-Object { Write-Host $_; if (-not $opened -and $_ -match 'Ready in') { $opened = $true; Start-Process 'http://127.0.0.1:30141' } }"
pause
