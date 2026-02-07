@echo off
echo Starting Python Auth Backend...
cd /d "%~dp0Hiring-and-Assesment-Portal\backend"

REM Check if virtual environment exists
if exist "venv311\Scripts\activate.bat" (
    call venv311\Scripts\activate.bat
) else (
    echo Creating virtual environment...
    python -m venv venv311
    call venv311\Scripts\activate.bat
    echo Installing requirements...
    pip install -r requirements.txt
)

REM Check for .env file
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env"
        echo Created .env from .env.example - Please update with your credentials!
    )
)

echo Starting Flask server on port 5000...
python app.py
