@echo off
godot_console --headless --path . res://tests/run_tests.tscn 1>out.txt 2>err.txt
set CODE=%errorlevel%
type out.txt
type err.txt
if %CODE% neq 0 (echo === TESTS FAILED === & exit /b 1)
findstr /C:"SCRIPT ERROR" /C:"Parse Error" out.txt err.txt >nul && (echo === SCRIPT ERRORS === & exit /b 1)
echo === OK ===
exit /b 0