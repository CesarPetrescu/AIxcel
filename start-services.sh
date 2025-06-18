#!/bin/bash

# AIxcel Startup Script
# This script starts both the backend and frontend services

echo "Starting AIxcel services..."

# Start backend in background
echo "Starting Rust backend on port 6889..."
cd backend
cargo run &
BACKEND_PID=$!

# Wait a moment for backend to start
sleep 3

# Start frontend
echo "Starting Next.js frontend on port 3000..."
cd ../frontend
npm run dev &
FRONTEND_PID=$!

echo "AIxcel is starting up..."
echo "Backend PID: $BACKEND_PID"
echo "Frontend PID: $FRONTEND_PID"
echo ""
echo "Services will be available at:"
echo "  Frontend: http://192.168.10.161:3000"
echo "  Backend:  http://192.168.10.161:6889"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for services and handle shutdown
trap 'echo "Shutting down..."; kill $BACKEND_PID $FRONTEND_PID; exit' INT

wait
