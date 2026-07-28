@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-web.ps1
exit /b %errorlevel%
