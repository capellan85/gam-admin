#!/bin/bash
cd "$(dirname "$0")"
.venv/bin/uvicorn main:app --port 8000 &
SERVER_PID=$!
sleep 1
open http://localhost:8000
echo "GAM Admin UI is running at http://localhost:8000"
echo "Press Ctrl+C to stop."
wait $SERVER_PID
