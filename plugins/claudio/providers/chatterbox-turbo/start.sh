#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8004}"
LOG_FILE="${LOG_FILE:-/tmp/chatterbox.log}"

# Check if server exists
if [ ! -f "$PROVIDER_DIR/chatterbox-tts/server.py" ]; then
    echo "❌ Chatterbox not installed. Run install first."
    exit 1
fi

# Check if already running
if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID=$(lsof -ti ":$PORT")
    echo "⚠️  Chatterbox already running on port $PORT (PID: $PID)"
    exit 0
fi

# Start server
echo "▶️  Starting Chatterbox TTS on port $PORT..."
echo "   (Model may download on first run, this can take a few minutes)"
cd "$PROVIDER_DIR/chatterbox-tts"
nohup ./venv/bin/python server.py > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Wait for server to start (up to 30 minutes for first-time model download)
echo "   Waiting for server to start..."
MAX_WAIT=360  # 360 iterations * 5 seconds = 30 minutes
HEALTH_URL="http://127.0.0.1:$PORT/"

for i in $(seq 1 $MAX_WAIT); do
    sleep 5

    # Check if process is still alive
    if ! ps -p $SERVER_PID > /dev/null 2>&1; then
        echo "❌ Server process died. Check $LOG_FILE"
        tail -20 "$LOG_FILE" | grep -i error || tail -5 "$LOG_FILE"
        exit 1
    fi

    # Check if port is listening
    if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        # Port is up, now check health endpoint
        if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
            echo "✓ Chatterbox started and ready (PID: $SERVER_PID)"
            echo "$SERVER_PID"  # Output PID for state management
            exit 0
        fi
    fi

    # Show progress indication every 30 seconds
    if [ $((i % 6)) -eq 0 ]; then
        elapsed=$((i * 5))
        echo "   Still waiting... (${elapsed}s elapsed)"
        if [ $i -lt 72 ]; then
            echo "   Model may be downloading (first run can take 5-20 minutes)"
        fi
    fi
done

# Timeout after 30 minutes
echo "❌ Server failed to start within 30 minutes"
echo "   Check $LOG_FILE for details"
if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "   Process is still running but not responding - killing it"
    kill $SERVER_PID 2>/dev/null || true
fi
exit 1
