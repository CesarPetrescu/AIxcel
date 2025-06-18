@echo off
REM AIXcel Startup Script for Windows
REM This script starts both the backend and frontend servers

echo 🚀 Starting AIXcel...
echo.

REM Check if we're in the right directory
if not exist "backend\" (
    echo ❌ Error: Please run this script from the AIXcel\AIxcel directory
    echo    Current directory: %CD%
    echo    Expected structure: backend\ and frontend\ folders
    pause
    exit /b 1
)

if not exist "frontend\" (
    echo ❌ Error: Please run this script from the AIXcel\AIxcel directory
    echo    Current directory: %CD%
    echo    Expected structure: backend\ and frontend\ folders
    pause
    exit /b 1
)

echo 📦 Starting Backend (Rust/Actix)...
start "AIXcel Backend" cmd /c "cd backend && cargo run"

echo ⏳ Waiting for backend to start...
timeout /t 3 /nobreak >nul

echo 🌐 Starting Frontend (Next.js)...
cd frontend

REM Install dependencies if node_modules doesn't exist
if not exist "node_modules\" (
    echo 📥 Installing frontend dependencies...
    call npm install
)

start "AIXcel Frontend" cmd /c "npm run dev"
cd ..

echo.
echo ✅ AIXcel is starting up!
echo.
echo 🔗 URLs:
echo    Frontend: http://localhost:3000
echo    Backend:  http://localhost:6889
echo.
echo 💡 Usage:
echo    - Double-click cells to edit
echo    - Try formulas like =SUM(1,2,3)
echo    - Right-click for formatting options
echo    - Open multiple tabs for real-time collaboration
echo.
echo 🛑 Close the terminal windows to stop the servers
echo.
pause
