#!/bin/bash

# AIXcel Startup Script
# This script starts both the backend and frontend servers

echo "🚀 Starting AIXcel..."
echo ""

# Check if we're in the right directory
if [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    echo "❌ Error: Please run this script from the AIXcel/AIxcel directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected structure: backend/ and frontend/ folders"
    exit 1
fi

# Function to cleanup background processes
cleanup() {
    echo ""
    echo "🛑 Stopping servers..."
    jobs -p | xargs -r kill
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT

echo "📦 Starting Backend (Rust/Actix)..."
cd backend
cargo run &
BACKEND_PID=$!
cd ..

echo "⏳ Waiting for backend to start..."
sleep 3

echo "🌐 Starting Frontend (Next.js)..."
cd frontend

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📥 Installing frontend dependencies..."
    npm install
fi

npm run dev &
FRONTEND_PID=$!
cd ..

echo ""
echo "✅ AIXcel is starting up!"
echo ""
echo "🔗 URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://localhost:6889"
echo "   Network:  http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "💡 Usage:"
echo "   - Double-click cells to edit"
echo "   - Try formulas like =SUM(1,2,3)"
echo "   - Right-click for formatting options"
echo "   - Open multiple tabs for real-time collaboration"
echo ""
echo "🛑 Press Ctrl+C to stop both servers"
echo ""

# Wait for background processes
wait $BACKEND_PID $FRONTEND_PID
