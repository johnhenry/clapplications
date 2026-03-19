#!/bin/bash

PORT="${PORT:-2022}"

# Check if lsof is available
if ! command -v lsof >/dev/null 2>&1; then
    echo "error: lsof not found"
    exit 2
fi

# Check if server is listening on port (single lsof call to avoid race condition)
PID=$(lsof -ti ":$PORT" 2>/dev/null)
if [ -n "$PID" ] && lsof -Pi ":$PORT" -sTCP:LISTEN -p "$PID" >/dev/null 2>&1; then
    echo "running $PID"
    exit 0
else
    echo "stopped"
    exit 1
fi
