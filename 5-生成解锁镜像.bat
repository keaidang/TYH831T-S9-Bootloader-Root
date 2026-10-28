@echo off
title TYH831T - 5-??????.bat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build.ps1"
pause
