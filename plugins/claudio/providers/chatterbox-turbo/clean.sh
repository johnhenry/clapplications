#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-servers}"  # servers, models, or all

case "$TARGET" in
    servers)
        echo "🧹 Cleaning Chatterbox server installation..."
        if [ -d "$PROVIDER_DIR/chatterbox-tts" ]; then
            # Keep models in ~/.cache/huggingface, remove server files
            rm -rf "$PROVIDER_DIR/chatterbox-tts/venv"
            rm -f "$PROVIDER_DIR/chatterbox-tts/server.py"
            echo "✓ Removed Chatterbox server (models cached separately)"
        fi
        ;;
    models)
        echo "🧹 Cleaning Chatterbox models..."
        # Chatterbox models are in HuggingFace cache
        if [ -d "$HOME/.cache/huggingface/hub" ]; then
            # Find and remove chatterbox model cache
            find "$HOME/.cache/huggingface/hub" -name "*chatterbox*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed Chatterbox models from cache"
        fi
        ;;
    all)
        echo "🧹 Cleaning all Chatterbox files..."
        if [ -d "$PROVIDER_DIR/chatterbox-tts" ]; then
            rm -rf "$PROVIDER_DIR/chatterbox-tts"
            echo "✓ Removed Chatterbox server"
        fi
        if [ -d "$HOME/.cache/huggingface/hub" ]; then
            find "$HOME/.cache/huggingface/hub" -name "*chatterbox*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed Chatterbox models from cache"
        fi
        ;;
    *)
        echo "Usage: $0 {servers|models|all}"
        exit 1
        ;;
esac
