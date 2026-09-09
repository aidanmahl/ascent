@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-campaign.ps1
exit /b %errorlevel%
