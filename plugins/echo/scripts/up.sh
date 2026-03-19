#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
shift  # Remove plugin dir from args

# Source state management
source "$SCRIPT_DIR/state.sh"

# Parse arguments (stt=sensevoice tts=qwen3-tts)
STT_PROVIDER=$(get_provider "stt")
TTS_PROVIDER=$(get_provider "tts")

for arg in "$@"; do
    case "$arg" in
        stt=*)
            STT_PROVIDER="${arg#*=}"
            set_provider "stt" "$STT_PROVIDER"
            ;;
        tts=*)
            TTS_PROVIDER="${arg#*=}"
            set_provider "tts" "$TTS_PROVIDER"
            ;;
    esac
done

echo "🚀 Starting voice services..."
echo "   STT: $STT_PROVIDER"
echo "   TTS: $TTS_PROVIDER"
echo ""

# Function to ensure provider is installed and started
start_provider() {
    local provider="$1"
    local type="$2"  # stt or tts
    local port="$3"

    local provider_dir="$PLUGIN_DIR/providers/$provider"

    if [ ! -d "$provider_dir" ]; then
        echo "❌ Provider '$provider' not found"
        return 1
    fi

    # Check if already running
    local health_output=$("$provider_dir/health.sh" 2>/dev/null || echo "stopped")
    if [[ "$health_output" =~ ^running ]]; then
        local pid=$(echo "$health_output" | awk '{print $2}')
        echo "⚠️  $provider already running (PID: $pid)"
        return 0
    fi

    # Install if needed
    if [ ! -f "$provider_dir/.installed" ]; then
        echo "📥 Installing $provider..."
        if PORT="$port" "$provider_dir/install.sh"; then
            touch "$provider_dir/.installed"
        else
            echo "❌ Failed to install $provider"
            return 1
        fi
    fi

    # Start server
    echo "▶️  Starting $provider..."
    local pid_output=$(PORT="$port" "$provider_dir/start.sh")
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Extract PID from output (last line)
        local pid=$(echo "$pid_output" | tail -1 | grep -o '[0-9]\+' | head -1)
        if [ -n "$pid" ]; then
            set_server "$provider" "$pid" "$port" "running"
        fi
        return 0
    else
        echo "❌ Failed to start $provider"
        return 1
    fi
}

# Start STT provider
if ! start_provider "$STT_PROVIDER" "stt" 2022; then
    echo ""
    echo "❌ Failed to start STT provider"
    exit 1
fi

echo ""

# Start TTS provider
if ! start_provider "$TTS_PROVIDER" "tts" 8004; then
    echo ""
    echo "❌ Failed to start TTS provider"
    echo ""
    echo "📋 Check logs: /tmp/qwen3-tts.log"
    exit 1
fi

# Configure voice-mode MCP server
echo "🔧 Configuring voice-mode MCP..."

# Track if MCP configuration status
MCP_NEEDS_RESTART=false

# Check if voice-mode is already configured
if claude mcp get voice-mode &>/dev/null; then
    echo "✓ voice-mode MCP already configured"
    # Even if configured, it might not be loaded if Claude Code hasn't been restarted
    # We'll check this below by trying to detect if the session has access to voice tools
else
    # Add voice-mode MCP server with environment variables
    mcp_config=$(cat <<'EOF'
{
  "type": "stdio",
  "command": "uvx",
  "args": ["voice-mode"],
  "env": {
    "VOICEMODE_STT_BASE_URLS": "http://127.0.0.1:2022/v1",
    "VOICEMODE_TTS_BASE_URLS": "http://127.0.0.1:8004/v1"
  }
}
EOF
)

    if claude mcp add-json voice-mode "$mcp_config" --scope user; then
        echo "✓ voice-mode MCP configured"
        MCP_NEEDS_RESTART=true
    else
        echo "⚠️  Failed to configure voice-mode MCP (you may need to configure manually)"
    fi
fi

echo ""
echo "✅ Voice services ready!"
echo ""

# Always show restart reminder if MCP was just configured OR if we can't verify it's loaded
# Since we can't reliably detect if MCP is loaded in the current session, we show the
# restart reminder whenever MCP is configured but this might be first run
if [ "$MCP_NEEDS_RESTART" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  IMPORTANT: RESTART REQUIRED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "   Voice-mode MCP server was just configured."
    echo "   You MUST restart Claude Code for it to load."
    echo ""
    echo "   Steps:"
    echo "   1. Exit Claude Code (type /exit or close the application)"
    echo "   2. Restart Claude Code"
    echo "   3. Ask Claude: \"Let's have a voice conversation\""
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "💡 To start a voice conversation, just ask Claude naturally:"
    echo "   \"Let's have a voice conversation\""
    echo ""
    echo "   Note: If voice tools aren't available, you may need to restart"
    echo "   Claude Code. MCP servers only load on startup."
fi
