@echo off
title TYH831T - 1 install driver
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\driver.ps1"
