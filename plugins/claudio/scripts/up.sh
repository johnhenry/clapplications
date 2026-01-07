#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
shift  # Remove plugin dir from args

# Source state management
source "$SCRIPT_DIR/state.sh"

# Parse arguments (stt=whisper tts=chatterbox-turbo)
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

    # Check if it's chatterbox-turbo and provide HuggingFace auth help
    if [ "$TTS_PROVIDER" = "chatterbox-turbo" ]; then
        echo ""
        echo "⚠️  TTS service failed. This is likely due to missing HuggingFace authentication."
        echo ""
        echo "📝 To fix this:"
        echo "   1. Get a token from: https://huggingface.co/settings/tokens"
        echo "   2. Run:"
        echo "      cd $PLUGIN_DIR/providers/chatterbox-turbo/chatterbox-tts"
        echo "      source venv/bin/activate"
        echo "      huggingface-cli login --token YOUR_TOKEN"
        echo ""
        echo "💡 See the README for more details: $PLUGIN_DIR/README.md"
        echo "📋 Check logs: /tmp/chatterbox.log"
    fi

    exit 1
fi

# Configure voice-mode MCP server
echo "🔧 Configuring voice-mode MCP..."

# Track if MCP was just installed
MCP_JUST_INSTALLED=false

# Check if voice-mode is already configured
if claude mcp get voice-mode &>/dev/null; then
    echo "✓ voice-mode MCP already configured"
else
    # Add voice-mode MCP server with environment variables
    mcp_config=$(cat <<'EOF'
{
  "type": "stdio",
  "command": "uvx",
  "args": ["voice-mode"],
  "env": {
    "VOICEMODE_STT_BASE_URL": "http://127.0.0.1:2022/v1",
    "VOICEMODE_TTS_BASE_URL": "http://127.0.0.1:8004/v1"
  }
}
EOF
)

    if claude mcp add-json voice-mode "$mcp_config" --scope user; then
        echo "✓ voice-mode MCP configured"
        MCP_JUST_INSTALLED=true
    else
        echo "⚠️  Failed to configure voice-mode MCP (you may need to configure manually)"
    fi
fi

echo ""

# Check if chatterbox-turbo was just installed and warn about HuggingFace auth
if [ "$TTS_PROVIDER" = "chatterbox-turbo" ]; then
    provider_dir="$PLUGIN_DIR/providers/chatterbox-turbo/chatterbox-tts"
    if [ -d "$provider_dir/venv" ]; then
        # Check if HuggingFace token exists
        if ! "$provider_dir/venv/bin/python" -c "from huggingface_hub import get_token; token = get_token(); exit(0 if token else 1)" 2>/dev/null; then
            echo "⚠️  IMPORTANT: HuggingFace authentication required!"
            echo ""
            echo "   Before using voice features, you must authenticate:"
            echo ""
            echo "   1. Get a token from: https://huggingface.co/settings/tokens"
            echo "   2. Run:"
            echo "      cd $provider_dir"
            echo "      source venv/bin/activate"
            echo "      huggingface-cli login --token YOUR_TOKEN"
            echo ""
            echo "   See README for details: $PLUGIN_DIR/README.md"
            echo ""
        fi
    fi
fi

echo "✅ Voice services ready!"
echo ""

# If MCP was just installed, remind user to restart Claude Code
if [ "$MCP_JUST_INSTALLED" = true ]; then
    echo "⚠️  IMPORTANT: Restart Claude Code to activate the voice-mode MCP server"
    echo ""
    echo "   After restarting, just ask Claude: \"Let's have a voice conversation\""
else
    echo "Just ask Claude: \"Let's have a voice conversation\""
fi
