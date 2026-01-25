#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$(dirname "$(dirname "$PROVIDER_DIR")")/scripts"
PORT="${PORT:-8004}"

# Source shutdown helpers
source "$SCRIPT_DIR/shutdown.sh"

# Stop by port
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    stop_by_port "$PORT" "Qwen3-TTS"
    if [ $? -eq 0 ]; then
        echo "✓ Stopped Qwen3-TTS"
        exit 0
    else
        exit 1
    fi
else
    echo "ℹ️  Qwen3-TTS not running"
    exit 0
fi
