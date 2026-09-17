@echo off
setlocal
cd /d "%~dp0" || exit /b 1
title Pi Web
echo Starting Pi Web. Keep this window open; press Ctrl+C to stop.
powershell.exe -NoProfile -Command "$opened = $false; & npm.cmd run dev 2>&1 | ForEach-Object { Write-Host $_; if (-not $opened -and $_ -match 'Ready in') { $opened = $true; Start-Process 'http://127.0.0.1:30141' } }"
pause
