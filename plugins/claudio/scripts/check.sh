#!/bin/bash

# Check if voice setup is complete and ready to use

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"

source "$SCRIPT_DIR/state.sh"

echo "🔍 Checking voice conversation setup..."
echo ""

# Check 1: STT Service
echo "1️⃣  Checking STT service (Whisper)..."
STT_PROVIDER=$(get_provider "stt")
if [ -z "$STT_PROVIDER" ]; then
    STT_PROVIDER="whisper"
fi

STT_HEALTH=$("$PLUGIN_DIR/providers/$STT_PROVIDER/health.sh" 2>/dev/null || echo "stopped")
if [[ "$STT_HEALTH" =~ ^running ]]; then
    PID=$(echo "$STT_HEALTH" | awk '{print $2}')
    echo "   ✅ $STT_PROVIDER is running (PID: $PID)"
else
    echo "   ❌ $STT_PROVIDER is not running"
    echo "      Run: /claudio:up"
    exit 1
fi

echo ""

# Check 2: TTS Service
echo "2️⃣  Checking TTS service (Chatterbox)..."
TTS_PROVIDER=$(get_provider "tts")
if [ -z "$TTS_PROVIDER" ]; then
    TTS_PROVIDER="chatterbox-turbo"
fi

TTS_HEALTH=$("$PLUGIN_DIR/providers/$TTS_PROVIDER/health.sh" 2>/dev/null || echo "stopped")
if [[ "$TTS_HEALTH" =~ ^running ]]; then
    PID=$(echo "$TTS_HEALTH" | awk '{print $2}')
    echo "   ✅ $TTS_PROVIDER is running (PID: $PID)"
else
    echo "   ❌ $TTS_PROVIDER is not running"
    echo "      Run: /claudio:up"
    exit 1
fi

echo ""

# Check 3: MCP Configuration
echo "3️⃣  Checking voice-mode MCP configuration..."
if claude mcp get voice-mode &>/dev/null; then
    echo "   ✅ voice-mode MCP is configured"
else
    echo "   ❌ voice-mode MCP is not configured"
    echo "      Run: /claudio:up"
    exit 1
fi

echo ""

# Check 4: MCP Server Loaded (best effort)
echo "4️⃣  Checking if voice-mode MCP is loaded..."
echo "   ⚠️  Cannot verify if MCP is loaded in current session"
echo "      MCP servers only load when Claude Code starts"
echo ""
echo "   If you just configured voice-mode or recently ran /claudio:up,"
echo "   you need to restart Claude Code for voice tools to work."
echo ""

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Voice services are running"
echo "✅ MCP configuration is present"
echo ""
echo "To use voice conversations:"
echo "  1. Make sure you've restarted Claude Code at least once since"
echo "     running /claudio:up"
echo "  2. Ask Claude naturally: \"Let's have a voice conversation\""
echo ""
echo "If voice doesn't work, try:"
echo "  • Restart Claude Code (MCP servers load on startup)"
echo "  • Run /claudio:status to check service status"
echo "  • Check logs: /tmp/whisper.log and /tmp/chatterbox.log"
echo ""
