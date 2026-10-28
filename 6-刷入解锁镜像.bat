@echo off
title TYH831T - 6 flash unlock image
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\flash.ps1" -Partition uboot_b -Image "%~dp0out\uboot_b_magic64.img"