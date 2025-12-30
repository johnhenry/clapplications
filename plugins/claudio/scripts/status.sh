#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"

# Source state management
source "$SCRIPT_DIR/state.sh"

echo "Voice Mode Status"
echo "━━━━━━━━━━━━━━━━━"
echo ""

# Get current providers
STT_PROVIDER=$(get_provider "stt")
TTS_PROVIDER=$(get_provider "tts")

echo "Providers"
echo "  └─ STT: $STT_PROVIDER"
echo "  └─ TTS: $TTS_PROVIDER"
echo ""

# Check installations
echo "Installations"
for provider in "$STT_PROVIDER" "$TTS_PROVIDER"; do
    if [ -f "$PLUGIN_DIR/providers/$provider/.installed" ]; then
        echo "  └─ $provider: ✓ Installed"
    else
        echo "  └─ $provider: ✗ Not installed"
    fi
done
echo ""

# Check STT status
echo "Speech-to-Text ($STT_PROVIDER)"
stt_health=$(PORT=2022 "$PLUGIN_DIR/providers/$STT_PROVIDER/health.sh" 2>/dev/null || echo "stopped")
if [[ "$stt_health" =~ ^running ]]; then
    pid=$(echo "$stt_health" | awk '{print $2}')
    echo "  └─ Status: ✓ Running"
    echo "  └─ URL: http://127.0.0.1:2022/v1"
    echo "  └─ PID: $pid"
else
    echo "  └─ Status: ✗ Stopped"
    echo "  └─ URL: http://127.0.0.1:2022/v1"
fi
echo ""

# Check TTS status
echo "Text-to-Speech ($TTS_PROVIDER)"
tts_health=$(PORT=8004 "$PLUGIN_DIR/providers/$TTS_PROVIDER/health.sh" 2>/dev/null || echo "stopped")
if [[ "$tts_health" =~ ^running ]]; then
    pid=$(echo "$tts_health" | awk '{print $2}')
    echo "  └─ Status: ✓ Running"
    echo "  └─ URL: http://127.0.0.1:8004/v1"
    echo "  └─ PID: $pid"
else
    echo "  └─ Status: ✗ Stopped"
    echo "  └─ URL: http://127.0.0.1:8004/v1"
fi
echo ""

# Check MCP configuration
echo "MCP Configuration"
if claude mcp get voice-mode &>/dev/null; then
    mcp_status=$(claude mcp get voice-mode 2>&1 | grep "Status:" | cut -d: -f2- | xargs)
    if [[ "$mcp_status" =~ "Connected" ]]; then
        echo "  └─ voice-mode: ✓ Connected"
    else
        echo "  └─ voice-mode: ⚠️  Configured but not connected"
    fi
else
    echo "  └─ voice-mode: ✗ Not configured"
fi
echo ""

# Overall status
if [[ "$stt_health" =~ ^running ]] && [[ "$tts_health" =~ ^running ]]; then
    echo "✅ Ready for voice mode"
else
    echo "⚠️  Services not running. Use /claudio:up to start them"
fi
