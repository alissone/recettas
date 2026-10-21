@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "VENV_PY=%SCRIPT_DIR%.venv\Scripts\python.exe"

if not exist "%VENV_PY%" (
    echo Virtual environment not found. Run setup.bat first.
    pause
    exit /b 1
)

title Recettas transcriber
"%VENV_PY%" "%SCRIPT_DIR%worker.py"
pause
