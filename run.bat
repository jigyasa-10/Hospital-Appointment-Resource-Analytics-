@echo off
rem One-click start for Windows. Double-click this file.
cd /d "%~dp0"

if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
)
call ".venv\Scripts\activate"

echo Installing requirements...
pip install -q -r requirements.txt

if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo.
    echo A new .env file was created. Open it, set DB_SERVER to your SSMS server name,
    echo save it, then run this file again.
    notepad ".env"
    pause
    exit /b
)

echo.
echo Starting the dashboard at http://127.0.0.1:5000
start "" http://127.0.0.1:5000
python app.py
pause
