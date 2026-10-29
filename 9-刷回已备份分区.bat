@echo off
title TYH831T - 9 restore all backed-up partitions
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\restore_all.ps1"
pause
