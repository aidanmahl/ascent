@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate.ps1
exit /b %errorlevel%