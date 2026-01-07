#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="${MODEL:-base.en}"

echo "📥 Installing Whisper STT provider..."

# Check required dependencies
for cmd in git make cmake; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ Error: $cmd is not installed"
        echo "   Please install $cmd and try again"
        exit 1
    fi
done

# Clone whisper.cpp if not exists
if [ ! -d "$PROVIDER_DIR/whisper.cpp" ]; then
    echo "📥 Cloning whisper.cpp..."
    git clone https://github.com/ggml-org/whisper.cpp.git "$PROVIDER_DIR/whisper.cpp"
    echo "✓ Cloned whisper.cpp"
else
    echo "✓ whisper.cpp already exists"
fi

# Build whisper.cpp
if [ ! -f "$PROVIDER_DIR/whisper.cpp/build/bin/whisper-server" ]; then
    echo "🔨 Building whisper.cpp..."
    cd "$PROVIDER_DIR/whisper.cpp"
    make build
    echo "✓ Built whisper.cpp"
else
    echo "✓ whisper.cpp already built"
fi

# Download model if not exists
MODEL_FILE="$PROVIDER_DIR/whisper.cpp/models/ggml-$MODEL.bin"
if [ ! -f "$MODEL_FILE" ]; then
    echo "📥 Downloading $MODEL model..."
    bash "$PROVIDER_DIR/whisper.cpp/models/download-ggml-model.sh" "$MODEL"
    echo "✓ Downloaded $MODEL model"
else
    echo "✓ Model $MODEL already exists"
fi

echo "✅ Whisper provider installed"
