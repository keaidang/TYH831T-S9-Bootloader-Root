@echo off
title TYH831T - 4-????.bat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\verify.ps1"
pause
