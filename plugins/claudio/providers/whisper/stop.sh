#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$(dirname "$(dirname "$PROVIDER_DIR")")/scripts"
PORT="${PORT:-2022}"

# Source shutdown helpers
source "$SCRIPT_DIR/shutdown.sh"

# Stop by port
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    stop_by_port "$PORT" "Whisper STT"
    if [ $? -eq 0 ]; then
        echo "✓ Stopped Whisper STT"
        exit 0
    else
        exit 1
    fi
else
    echo "ℹ️  Whisper not running"
    exit 0
fi
