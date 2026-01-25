# Claudio Voice Plugin for Claude Code

Voice mode plugin that enables hands-free conversation with Claude using SenseVoice (speech-to-text) and Qwen3-TTS (text-to-speech) - both from the Alibaba ecosystem.

## Features

- **Local Speech Recognition** - SenseVoice for fast, accurate STT (15x faster than Whisper-Large)
- **High-Quality TTS** - Qwen3-TTS with natural voice synthesis
- **No Authentication Required** - Both models are fully open, no HuggingFace tokens needed
- **Natural Language Control** - Just ask Claude to use voice, no special commands
- **Self-Contained** - Everything bundled, no separate installations
- **Privacy-First** - All processing happens locally
- **GPU Accelerated** - Automatic CUDA/MPS detection
- **Provider Architecture** - Easy to add new STT/TTS providers

## Quick Start

### Prerequisites

- Python 3.10+ (3.11 recommended)
- 8GB+ RAM (16GB recommended)
- Optional: NVIDIA GPU with 8GB+ VRAM for best performance

### Installation

1. Copy this plugin directory to your Claude Code plugins folder
2. Start voice services with `/claudio:up` (installs automatically if needed)
3. **If this is your first time**: Restart Claude Code to activate the MCP server

### Usage

```bash
# Start voice services (installs if needed)
/claudio:up

# IMPORTANT: If this is your first time running /claudio:up:
# You MUST restart Claude Code for the voice-mode MCP server to become available!

# Then just talk naturally to Claude:
"Let's have a voice conversation"
"Can we talk using voice?"
"Switch to voice mode"

# When done, just say:
"Back to text mode"
"Stop using voice"
```

**That's it!** Once services are running, Claude automatically uses voice when you ask naturally. No special commands needed!

**First-time setup:** The first time you run `/claudio:up`, you must restart Claude Code to activate the voice-mode MCP server.

> **Having trouble with first-time setup?** See [FIRST_TIME_SETUP.md](./FIRST_TIME_SETUP.md) for a detailed explanation of why restart is required and troubleshooting steps.

## Available Commands

| Command | Description |
|---------|-------------|
| `/claudio:up [stt=sensevoice] [tts=qwen3-tts]` | Start voice services (installs if needed) |
| `/claudio:down` | Stop all voice services |
| `/claudio:status` | Display comprehensive service status |
| `/claudio:check` | Verify complete setup and troubleshoot issues |
| `/claudio:clean servers` | Remove server installations, keep models |
| `/claudio:clean models` | Remove all downloaded models |
| `/claudio:clean all` | Remove everything (complete cleanup) |

**Voice conversation**: Just ask Claude naturally! "Let's talk with voice" or "Switch to voice mode"

## How It Works

The plugin integrates with Claude Code's voice-mode MCP server. Once you run `/claudio:up`:

1. **SenseVoice** and **Qwen3-TTS** servers start in the background
2. The **voice-mode MCP** is automatically configured in Claude Code
3. Claude automatically has access to voice capabilities

**Everything is configured for you!** The plugin:
- Installs voice providers (SenseVoice, Qwen3-TTS)
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
- Python 3.10+ (3.11 recommended)
- `lsof` (for process management)
- 4GB+ free disk space

### Recommended (for better performance)
- NVIDIA GPU with 8GB+ VRAM (CUDA 12.1+)
- OR Apple Silicon with Metal (MPS)
- 16GB RAM

### Hardware Requirements by Provider

| Provider | VRAM (GPU) | RAM (CPU) | Notes |
|----------|------------|-----------|-------|
| SenseVoice | ~2GB | ~4GB | 15x faster than Whisper-Large |
| Qwen3-TTS (0.6B) | ~4GB | ~8GB | Default model, good quality |
| Qwen3-TTS (1.7B) | ~8GB | ~16GB | Higher quality (set QWEN_TTS_MODEL) |
| **Combined** | ~6-10GB | ~12GB | Both providers running |

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
    │   (claudio/providers/)  │
    │                         │
    │ ┌─────────────────────┐ │
    │ │ SenseVoice          │ │  Port 2022
    │ │ (STT - FunASR)      │ │
    │ └─────────────────────┘ │
    │                         │
    │ ┌─────────────────────┐ │
    │ │ Qwen3-TTS           │ │  Port 8004
    │ │ (TTS - FastAPI)     │ │
    │ └─────────────────────┘ │
    └─────────────────────────┘
```

## Configuration

### Default Ports
- **SenseVoice STT**: `http://127.0.0.1:2022/v1`
- **Qwen3-TTS**: `http://127.0.0.1:8004/v1`

### Environment Variables
The plugin automatically configures these for you:
```bash
VOICEMODE_STT_BASE_URLS="http://127.0.0.1:2022/v1"
VOICEMODE_TTS_BASE_URLS="http://127.0.0.1:8004/v1"
```

### Using the Larger TTS Model
For higher quality TTS (requires 8GB+ VRAM):
```bash
export QWEN_TTS_MODEL="Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
/claudio:up
```

## Installation Details

### What happens during `/claudio:up`:

**Everything is installed and configured automatically!**

The plugin uses a provider-based architecture where each provider (sensevoice, qwen3-tts) is self-contained.

**Automatic MCP Configuration:**
1. Checks if voice-mode MCP is already configured
2. If not, installs it via `uvx voice-mode`
3. Adds it to your Claude Code MCP servers (user scope)
4. Configures environment variables for STT/TTS endpoints

**SenseVoice Provider (`providers/sensevoice/`):**
1. Creates Python virtual environment
2. Installs FunASR package with PyTorch
3. Creates FastAPI server
4. Model downloads on first start (~500MB)
5. Total: ~2GB

**Qwen3-TTS Provider (`providers/qwen3-tts/`):**
1. Creates Python virtual environment
2. Installs official `qwen-tts` package
3. Creates FastAPI server
4. Model downloads on first start (~3GB for 0.6B model)
5. Total: ~4GB

### Provider Architecture

Each provider is completely independent with:
- `install.sh` - Install dependencies
- `start.sh` - Start the server
- `stop.sh` - Graceful shutdown
- `health.sh` - Check if running
- `clean.sh` - Remove components

This makes it easy to add new providers or switch between them!

## Troubleshooting

### Services won't start
```bash
# Check status
/claudio:status

# Stop and restart
/claudio:down
/claudio:up

# Check logs
tail -f /tmp/sensevoice.log
tail -f /tmp/qwen3-tts.log
```

### Model download issues
Both models download from public repositories without authentication:
- SenseVoice: Downloads from ModelScope
- Qwen3-TTS: Downloads from HuggingFace (public, no token needed)

If downloads fail, check your internet connection and try again.

### GPU not detected
Services will automatically fall back to CPU. For GPU support:
- **NVIDIA**: Install CUDA 12.1+
- **Apple**: macOS 12+ with Metal support

### Port conflicts
Edit port in provider start scripts:
```bash
# providers/sensevoice/start.sh
PORT="${PORT:-2022}"

# providers/qwen3-tts/start.sh
PORT="${PORT:-8004}"
```

### Out of memory
Try using CPU mode or the smaller TTS model:
```bash
# Force CPU for lower memory usage
export CUDA_VISIBLE_DEVICES=""
/claudio:up
```

## Advanced Usage

### Switching Providers
```bash
# Use specific providers
/claudio:up stt=sensevoice tts=qwen3-tts

# Then ask Claude to use voice naturally
# Claude will use whatever providers are currently running
```

### Manual Provider Control
```bash
# Start a specific provider manually
cd claudio/providers/sensevoice
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

**SenseVoice (via FunASR)**
- Implementation: Python + PyTorch
- Model: iic/SenseVoiceSmall
- Performance: 15x faster than Whisper-Large
- Languages: Chinese, English, Japanese, Korean, Cantonese
- License: MIT

**Qwen3-TTS**
- Implementation: Python + PyTorch
- Model: Qwen/Qwen3-TTS-12Hz-0.6B (default) or 1.7B
- Sample Rate: 24kHz
- Features: Multiple voices, natural prosody
- License: Apache 2.0

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

- **SenseVoice**: Alibaba FunAudioLLM
- **Qwen3-TTS**: Alibaba Qwen Team
- **FunASR**: ModelScope
- **Voice Mode MCP**: Anthropic
