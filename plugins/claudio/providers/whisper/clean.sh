#!/bin/bash

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-servers}"  # servers, models, or all

case "$TARGET" in
    servers)
        echo "🧹 Cleaning Whisper server installation..."
        if [ -d "$PROVIDER_DIR/whisper.cpp" ]; then
            # Keep models, remove everything else
            if [ -d "$PROVIDER_DIR/whisper.cpp/models" ]; then
                mkdir -p /tmp/whisper-models-backup
                mv "$PROVIDER_DIR/whisper.cpp/models"/* /tmp/whisper-models-backup/ 2>/dev/null || true
            fi
            rm -rf "$PROVIDER_DIR/whisper.cpp"
            mkdir -p "$PROVIDER_DIR/whisper.cpp/models"
            mv /tmp/whisper-models-backup/* "$PROVIDER_DIR/whisper.cpp/models/" 2>/dev/null || true
            rm -rf /tmp/whisper-models-backup
            echo "✓ Removed Whisper server (kept models)"
        fi
        ;;
    models)
        echo "🧹 Cleaning Whisper models..."
        if [ -d "$PROVIDER_DIR/whisper.cpp/models" ]; then
            find "$PROVIDER_DIR/whisper.cpp/models" -name "*.bin" -type f -delete 2>/dev/null || true
            echo "✓ Removed Whisper models"
        fi
        ;;
    all)
        echo "🧹 Cleaning all Whisper files..."
        if [ -d "$PROVIDER_DIR/whisper.cpp" ]; then
            rm -rf "$PROVIDER_DIR/whisper.cpp"
            echo "✓ Removed all Whisper files"
        fi
        ;;
    *)
        echo "Usage: $0 {servers|models|all}"
        exit 1
        ;;
esac
