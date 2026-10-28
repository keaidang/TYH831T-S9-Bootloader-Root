@echo off
title TYH831T - 8 rollback
cd /d "%~dp0"
echo  1 = rollback uboot_b (undo unlock)
echo  2 = rollback boot_b  (undo root)
set /p C=Choose:
if "%C%"=="1" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\flash.ps1" -Partition uboot_b -Rollback
if "%C%"=="2" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\flash.ps1" -Partition boot_b -Rollback