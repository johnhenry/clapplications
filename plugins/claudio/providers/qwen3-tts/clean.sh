#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-servers}"  # servers, models, or all

case "$TARGET" in
    servers)
        echo "🧹 Cleaning Qwen3-TTS server installation..."
        if [ -d "$PROVIDER_DIR/qwen3-tts" ]; then
            # Keep models in ~/.cache/huggingface, remove server files
            rm -rf "$PROVIDER_DIR/qwen3-tts/venv"
            rm -f "$PROVIDER_DIR/qwen3-tts/server.py"
            echo "✓ Removed Qwen3-TTS server (models cached separately)"
        fi
        ;;
    models)
        echo "🧹 Cleaning Qwen3-TTS models..."
        # Qwen3-TTS models are in HuggingFace cache
        if [ -d "$HOME/.cache/huggingface/hub" ]; then
            # Find and remove Qwen3-TTS model cache
            find "$HOME/.cache/huggingface/hub" -name "*Qwen3-TTS*" -type d -exec rm -rf {} + 2>/dev/null || true
            find "$HOME/.cache/huggingface/hub" -name "*qwen3-tts*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed Qwen3-TTS models from HuggingFace cache"
        fi
        ;;
    all)
        echo "🧹 Cleaning all Qwen3-TTS files..."
        if [ -d "$PROVIDER_DIR/qwen3-tts" ]; then
            rm -rf "$PROVIDER_DIR/qwen3-tts"
            echo "✓ Removed Qwen3-TTS server"
        fi
        if [ -d "$HOME/.cache/huggingface/hub" ]; then
            find "$HOME/.cache/huggingface/hub" -name "*Qwen3-TTS*" -type d -exec rm -rf {} + 2>/dev/null || true
            find "$HOME/.cache/huggingface/hub" -name "*qwen3-tts*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed Qwen3-TTS models from HuggingFace cache"
        fi
        ;;
    *)
        echo "Usage: $0 {servers|models|all}"
        exit 1
        ;;
esac
