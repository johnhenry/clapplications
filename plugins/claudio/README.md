# Claudio Voice Plugin for Claude Code

Voice mode plugin that enables hands-free conversation with Claude using Whisper (speech-to-text) and Chatterbox Turbo (text-to-speech).

## Features

- 🎤 **Local Speech Recognition** - Whisper.cpp for fast, private STT
- 🔊 **High-Quality TTS** - Chatterbox Turbo with 75ms latency
- 💬 **Natural Language Control** - Just ask Claude to use voice, no special commands
- 🚀 **Self-Contained** - Everything bundled, no separate installations
- 🔒 **Privacy-First** - All processing happens locally
- ⚡ **GPU Accelerated** - Automatic CUDA/ROCm/MPS detection
- 🔌 **Provider Architecture** - Easy to add new STT/TTS providers

## Quick Start

### Prerequisites

#### HuggingFace Authentication (Required for TTS)

The Chatterbox Turbo TTS provider requires a HuggingFace account and authentication token to download the voice model.

**Setup (required before first use):**
1. Create a free account at https://huggingface.co/
2. Generate an access token at https://huggingface.co/settings/tokens (read access is sufficient)
3. After running `/claudio:up`, authenticate with:
   ```bash
   cd ~/.claude/plugins/cache/clapplications/claudio/1.0.0/providers/chatterbox-turbo/chatterbox-tts
   source venv/bin/activate
   huggingface-cli login --token YOUR_TOKEN_HERE
   ```

**Note:** You only need to do this once. The token will be saved for future use.

### Installation

1. Copy this plugin directory to your Claude Code plugins folder
2. Start voice services with `/claudio:up` (installs automatically if needed)
3. **If this is your first time**: Restart Claude Code to activate the MCP server
4. Complete HuggingFace authentication (see Prerequisites above)

### Usage

```bash
# Start voice services (installs if needed)
/claudio:up

# Then just talk naturally to Claude:
"Let's have a voice conversation"
"Can we talk using voice?"
"Switch to voice mode"

# When done, just say:
"Back to text mode"
"Stop using voice"
```

**That's it!** Once services are running, Claude automatically uses voice when you ask naturally. No special commands needed!

## Available Commands

| Command | Description |
|---------|-------------|
| `/claudio:up [stt=whisper] [tts=chatterbox-turbo]` | Start voice services (installs if needed) |
| `/claudio:down` | Stop all voice services |
| `/claudio:status` | Display comprehensive service status |
| `/claudio:clean servers` | Remove server installations, keep models |
| `/claudio:clean models` | Remove all downloaded models |
| `/claudio:clean all` | Remove everything (complete cleanup) |

**Voice conversation**: Just ask Claude naturally! "Let's talk with voice" or "Switch to voice mode"

## How It Works

The plugin integrates with Claude Code's voice-mode MCP server. Once you run `/claudio:up`:

1. **Whisper** and **Chatterbox** servers start in the background
2. The **voice-mode MCP** is automatically configured in Claude Code
3. Claude automatically has access to voice capabilities

**Everything is configured for you!** The plugin:
- Installs voice providers (Whisper, Chatterbox)
- Configures the voice-mode MCP server
- Sets up environment variables
- Starts all services

**No special commands needed!** Just talk to Claude naturally:

```
You: "Let's have a voice conversation about Python"
Claude: [automatically uses voice-mode MCP tools to listen and speak]

You: "That's enough voice, back to text"
Claude: [stops using voice tools, continues in text]
```

The voice-mode MCP handles all the complexity - you just have a natural conversation with Claude.

## System Requirements

### Required
- Python 3.8+
- `git` (for cloning repositories)
- `make` (for building Whisper.cpp)
- `lsof` (for process management)
- 2GB+ free disk space

### Optional (for better performance)
- NVIDIA GPU with CUDA 12.1+ (Chatterbox Turbo)
- AMD GPU with ROCm (Chatterbox Turbo)
- Apple Silicon with Metal (Chatterbox Turbo via MPS)

## Architecture

```
Voice Services Stack:
┌─────────────────────────────────┐
│   Claude Code + Claudio Plugin  │
│   (/claudio:* commands)         │
└─────────────┬───────────────────┘
              │
              ▼
    ┌─────────────────────┐
    │   Voice Mode MCP    │
    │   (uvx voice-mode)  │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────────┐
    │   Local Voice Services  │
    │   (claudio/servers/)    │
    │                         │
    │ ┌─────────────────────┐ │
    │ │ Whisper.cpp         │ │  Port 2022
    │ │ (STT - base.en)     │ │
    │ └─────────────────────┘ │
    │                         │
    │ ┌─────────────────────┐ │
    │ │ Chatterbox Turbo    │ │  Port 8004
    │ │ (TTS - FastAPI)     │ │
    │ └─────────────────────┘ │
    └─────────────────────────┘
```

## Configuration

### Default Ports
- **Whisper STT**: `http://127.0.0.1:2022/v1`
- **Chatterbox TTS**: `http://127.0.0.1:8004/v1`

### Environment Variables
The plugin automatically configures these for you:
```bash
VOICEMODE_STT_BASE_URLS="http://127.0.0.1:2022/v1"
VOICEMODE_TTS_BASE_URLS="http://127.0.0.1:8004/v1"
```

## Installation Details

### What happens during `/claudio:up`:

**Everything is installed and configured automatically!**

The plugin uses a provider-based architecture where each provider (whisper, chatterbox-turbo) is self-contained.

**Automatic MCP Configuration:**
1. Checks if voice-mode MCP is already configured
2. If not, installs it via `uvx voice-mode`
3. Adds it to your Claude Code MCP servers (user scope)
4. Configures environment variables for STT/TTS endpoints

**Whisper Provider (`providers/whisper/`):**
1. Clones `whisper.cpp` repository
2. Builds with `make`
3. Downloads `base.en` model (~150MB)
4. Total: ~500MB

**Chatterbox Turbo Provider (`providers/chatterbox-turbo/`):**
1. Creates Python virtual environment
2. Installs official `chatterbox-tts` package (GPU-specific)
3. Creates FastAPI server
4. **⚠️ Requires HuggingFace authentication** - See Prerequisites section
5. Model downloads on first start (~2GB)
6. Total: ~2.5GB

### Provider Architecture

Each provider is completely independent with:
- `install.sh` - Install dependencies
- `start.sh` - Start the server
- `stop.sh` - Graceful shutdown
- `health.sh` - Check if running
- `clean.sh` - Remove components

This makes it easy to add new providers or switch between them!

## Troubleshooting

### TTS Service Won't Start (HuggingFace Authentication)

**Symptom:** `/claudio:status` shows chatterbox-turbo as "✗ Stopped"

**Common Error in `/tmp/chatterbox.log`:**
```
huggingface_hub.errors.LocalTokenNotFoundError: Token is required (`token=True`),
but no token found.
```

**Solution:** You need to authenticate with HuggingFace (see Prerequisites section above).

**Quick Fix:**
```bash
cd ~/.claude/plugins/cache/clapplications/claudio/1.0.0/providers/chatterbox-turbo/chatterbox-tts
source venv/bin/activate
huggingface-cli login --token YOUR_HF_TOKEN
```

Get your token from: https://huggingface.co/settings/tokens

**Verify Authentication:**
```bash
cd ~/.claude/plugins/cache/clapplications/claudio/1.0.0/providers/chatterbox-turbo/chatterbox-tts
source venv/bin/activate
python -c "from huggingface_hub import login; print('✓ Already logged in')" 2>/dev/null || echo "⚠️  Need to login"
```

### Services won't start (general)
```bash
# Check status
/claudio:status

# Stop and restart
/claudio:down
/claudio:up

# Check logs
tail -f /tmp/whisper.log
tail -f /tmp/chatterbox.log
```

### GPU not detected
Chatterbox will automatically fall back to CPU. For GPU support:
- **NVIDIA**: Install CUDA 12.1+
- **AMD**: Install ROCm
- **Apple**: macOS 12+ with Metal support

### Port conflicts
Edit port in provider start scripts:
```bash
# providers/whisper/start.sh
PORT="${PORT:-2022}"

# providers/chatterbox-turbo/start.sh
PORT="${PORT:-8004}"
```

### Voice quality issues
For better quality, use a different Whisper model:
```bash
# Set environment variable before /claudio:up
export MODEL="small.en"  # Options: tiny.en, base.en, small.en, medium.en
/claudio:up
```

## Advanced Usage

### Switching Providers
```bash
# Use different providers (future: openai, elevenlabs, etc.)
/claudio:up stt=whisper tts=chatterbox-turbo

# Then ask Claude to use voice naturally
# Claude will use whatever providers are currently running
```

### Manual Provider Control
```bash
# Start a specific provider manually
cd claudio/providers/whisper
./start.sh

# Stop a specific provider
./stop.sh

# Check health
./health.sh
```

### Cleanup Options
```bash
# Remove servers but keep models (fast reinstall)
/claudio:clean servers

# Remove models to free disk space
/claudio:clean models

# Complete cleanup
/claudio:clean all
```

## Technical Details

### Voice Stack Components

**Whisper.cpp**
- Implementation: C++ with GGML
- Model: base.en (74M parameters)
- Performance: ~50x real-time on Apple M2
- License: MIT

**Chatterbox Turbo**
- Implementation: Python + PyTorch
- Model: 350M parameters
- Performance: 75ms latency, 6x real-time
- Features: Paralinguistic tags, voice cloning, watermarking
- License: MIT

### MCP Servers

This plugin uses the official Voice Mode MCP server:

**Voice Mode MCP** (`uvx voice-mode`) - Conversation handling with STT/TTS integration

All service management is handled through bash scripts within the plugin directory.

## Contributing

This plugin is part of the Claudio project. See the main repository README for contribution guidelines.

## License

MIT License - See main repository for details.

## Support

- Issues: [GitHub Issues](https://github.com/your-username/claudio/issues)
- Documentation: See `mcp-server/ARCHITECTURE.md` for technical details
- Voice Mode: See official Claude Code voice mode documentation

## Credits

- **Whisper**: OpenAI (via ggerganov/whisper.cpp)
- **Chatterbox Turbo**: Resemble AI
- **Chatterbox TTS Server**: devnen
- **Voice Mode MCP**: Anthropic

claude --dangerously-skip-permissions -c --plugin-dir claudioclaude --dangerously-skip-permissions -c --plugin-dir claudio