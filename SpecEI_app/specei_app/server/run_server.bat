@echo off
echo Installing dependencies...
pip install -r requirements.txt
echo.
echo Starting Whisper Server...
python whisper_server.py
pause
