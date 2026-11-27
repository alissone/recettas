@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

python -m venv "%SCRIPT_DIR%.venv" || (pause & exit /b 1)
"%SCRIPT_DIR%.venv\Scripts\python.exe" -m pip install -r "%SCRIPT_DIR%requirements.txt" || (pause & exit /b 1)

REM Kokoro TTS (ONNX) for spoken replies in the assistant chat.
set "KOKORO_URL=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
if not exist "%SCRIPT_DIR%models" mkdir "%SCRIPT_DIR%models"
if not exist "%SCRIPT_DIR%models\kokoro-v1.0.onnx" curl -L -o "%SCRIPT_DIR%models\kokoro-v1.0.onnx" "%KOKORO_URL%/kokoro-v1.0.onnx"
if not exist "%SCRIPT_DIR%models\voices-v1.0.bin" curl -L -o "%SCRIPT_DIR%models\voices-v1.0.bin" "%KOKORO_URL%/voices-v1.0.bin"

if not exist "%SCRIPT_DIR%.env" (
    copy "%SCRIPT_DIR%.env.example" "%SCRIPT_DIR%.env" >nul
    echo Created .env - fill in SUPABASE_SERVICE_ROLE_KEY and ANTHROPIC_API_KEY.
)
pause
