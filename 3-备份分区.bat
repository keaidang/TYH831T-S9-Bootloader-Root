@echo off
title TYH831T - 3-????.bat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\backup.ps1"
pause
