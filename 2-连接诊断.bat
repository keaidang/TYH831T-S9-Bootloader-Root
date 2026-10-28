@echo off
title TYH831T - 2-????.bat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\diag.ps1"
pause
