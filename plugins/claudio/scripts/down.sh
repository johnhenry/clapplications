#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"

# Source state management
source "$SCRIPT_DIR/state.sh"

echo "🛑 Stopping voice services..."
echo ""

# Get all running servers from state
STT_PROVIDER=$(get_provider "stt")
TTS_PROVIDER=$(get_provider "tts")

# Stop each provider
for provider in "$STT_PROVIDER" "$TTS_PROVIDER"; do
    if [ -z "$provider" ]; then
        continue
    fi

    provider_dir="$PLUGIN_DIR/providers/$provider"
    if [ ! -d "$provider_dir" ]; then
        continue
    fi

    # Check if running
    health_output=$("$provider_dir/health.sh" 2>/dev/null || echo "stopped")
    if [[ "$health_output" =~ ^stopped ]]; then
        echo "ℹ️  $provider not running"
        continue
    fi

    # Stop server
    if "$provider_dir/stop.sh"; then
        remove_server "$provider"
    fi
done

echo ""
echo "✅ Voice services stopped"
