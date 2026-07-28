@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File tools\screenshot.ps1
exit /b %errorlevel%
