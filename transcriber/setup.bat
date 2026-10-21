@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

python -m venv "%SCRIPT_DIR%.venv" || (pause & exit /b 1)
"%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install -r "%SCRIPT_DIR%requirements.txt" || (pause & exit /b 1)

if not exist "%SCRIPT_DIR%.env" (
    copy "%SCRIPT_DIR%.env.example" "%SCRIPT_DIR%.env" >nul
    echo Created .env - fill in SUPABASE_SERVICE_ROLE_KEY and ANTHROPIC_API_KEY.
)
pause
