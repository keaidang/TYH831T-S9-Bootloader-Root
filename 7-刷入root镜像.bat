@echo off
title TYH831T - 7 flash root image
cd /d "%~dp0"
set "IMG=%~1"
if not defined IMG set /p IMG=Drag the magisk_patched .img here and press Enter: 
set "IMG=%IMG:"=%"
if not defined IMG goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\flash.ps1" -Partition boot_b -Image "%IMG%"