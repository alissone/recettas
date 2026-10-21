@echo off
setlocal

REM Called by worker.py: transcribe_one.bat <audio> <output dir> <model> <language>
REM Same conda env falar.bat and Summaries\transcribe.bat use.
set "CONDA_BAT=D:\anaconda3\condabin\conda.bat"
set "ENV_NAME=whisperx"

call "%CONDA_BAT%" activate "%ENV_NAME%"
if errorlevel 1 (
    echo Failed to activate Conda environment "%ENV_NAME%".
    exit /b 1
)

whisperx "%~1" --model %3 --language %4 --output_dir "%~2" --output_format txt
exit /b %errorlevel%
