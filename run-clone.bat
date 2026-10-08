@echo off
REM Launcher for clone-github-repos.ps1 - double-click to run.
REM -ExecutionPolicy Bypass applies only to this one run.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0clone-github-repos.ps1"
echo.
pause
