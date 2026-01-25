#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-servers}"  # servers, models, or all

case "$TARGET" in
    servers)
        echo "🧹 Cleaning SenseVoice server installation..."
        if [ -d "$PROVIDER_DIR/sensevoice" ]; then
            # Remove server files but keep models in cache
            rm -rf "$PROVIDER_DIR/sensevoice/venv"
            rm -f "$PROVIDER_DIR/sensevoice/server.py"
            echo "✓ Removed SenseVoice server (models cached separately)"
        fi
        ;;
    models)
        echo "🧹 Cleaning SenseVoice models..."
        # SenseVoice/FunASR models are cached in ~/.cache/modelscope
        if [ -d "$HOME/.cache/modelscope/hub" ]; then
            # Find and remove SenseVoice model cache
            find "$HOME/.cache/modelscope/hub" -name "*SenseVoice*" -type d -exec rm -rf {} + 2>/dev/null || true
            find "$HOME/.cache/modelscope/hub" -name "*sensevoice*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed SenseVoice models from ModelScope cache"
        fi
        # Also check for funasr cache
        if [ -d "$HOME/.cache/funasr" ]; then
            rm -rf "$HOME/.cache/funasr"
            echo "✓ Removed FunASR cache"
        fi
        ;;
    all)
        echo "🧹 Cleaning all SenseVoice files..."
        if [ -d "$PROVIDER_DIR/sensevoice" ]; then
            rm -rf "$PROVIDER_DIR/sensevoice"
            echo "✓ Removed SenseVoice server"
        fi
        if [ -d "$HOME/.cache/modelscope/hub" ]; then
            find "$HOME/.cache/modelscope/hub" -name "*SenseVoice*" -type d -exec rm -rf {} + 2>/dev/null || true
            find "$HOME/.cache/modelscope/hub" -name "*sensevoice*" -type d -exec rm -rf {} + 2>/dev/null || true
            echo "✓ Removed SenseVoice models from ModelScope cache"
        fi
        if [ -d "$HOME/.cache/funasr" ]; then
            rm -rf "$HOME/.cache/funasr"
            echo "✓ Removed FunASR cache"
        fi
        ;;
    *)
        echo "Usage: $0 {servers|models|all}"
        exit 1
        ;;
esac
