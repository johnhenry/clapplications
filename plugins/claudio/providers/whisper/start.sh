#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-2022}"
MODEL="${MODEL:-base.en}"
LOG_FILE="${LOG_FILE:-/tmp/whisper.log}"

# Check if server binary exists
if [ ! -f "$PROVIDER_DIR/whisper.cpp/build/bin/whisper-server" ]; then
    echo "❌ Whisper not installed. Run install first."
    exit 1
fi

# Check if already running
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID=$(lsof -ti ":$PORT")
    echo "⚠️  Whisper already running on port $PORT (PID: $PID)"
    exit 0
fi

# Start server
echo "▶️  Starting Whisper STT on port $PORT..."
cd "$PROVIDER_DIR/whisper.cpp"
nohup ./build/bin/whisper-server \
    -m "./models/ggml-$MODEL.bin" \
    --host 127.0.0.1 \
    --port "$PORT" \
    --request-path /v1/audio \
    --inference-path /transcriptions \
    > "$LOG_FILE" 2>&1 &

SERVER_PID=$!
sleep 2

# Verify it started
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✓ Whisper started (PID: $SERVER_PID)"
    echo "$SERVER_PID"  # Output PID for state management
    exit 0
else
    echo "❌ Failed to start Whisper. Check $LOG_FILE"
    exit 1
fi
