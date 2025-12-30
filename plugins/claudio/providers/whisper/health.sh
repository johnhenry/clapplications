#!/bin/bash

PORT="${PORT:-2022}"

# Check if server is listening on port
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID=$(lsof -ti ":$PORT")
    echo "running $PID"
    exit 0
else
    echo "stopped"
    exit 1
fi
