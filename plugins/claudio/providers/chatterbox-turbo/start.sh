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

# Wait up to 60 seconds for server to start
echo "   Waiting for server to start..."
for i in {1..12}; do
    sleep 5
    if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "✓ Chatterbox started (PID: $SERVER_PID)"
        echo "$SERVER_PID"  # Output PID for state management
        exit 0
    fi
    if ! ps -p $SERVER_PID > /dev/null 2>&1; then
        echo "❌ Server process died. Check $LOG_FILE"
        exit 1
    fi
done

# Still not up after 60s
echo "⏳ Server still starting (check $LOG_FILE)"
echo "   This is normal on first run while model downloads"
echo "$SERVER_PID"  # Output PID anyway
exit 0
