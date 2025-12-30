#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📥 Installing Chatterbox TTS provider..."

# Create chatterbox-tts directory if not exists
if [ ! -d "$PROVIDER_DIR/chatterbox-tts" ]; then
    mkdir -p "$PROVIDER_DIR/chatterbox-tts"
fi

cd "$PROVIDER_DIR/chatterbox-tts"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    # Use Python 3.11 or 3.12 (chatterbox-tts requires numpy that doesn't build on 3.13+)
    if command -v python3.11 &> /dev/null; then
        python3.11 -m venv venv
    elif command -v python3.12 &> /dev/null; then
        python3.12 -m venv venv
    else
        echo "⚠️  Warning: Python 3.11 or 3.12 not found, using default python3 (may fail on 3.13+)"
        python3 -m venv venv
    fi
    echo "✓ Created virtual environment"
else
    echo "✓ Virtual environment already exists"
fi

# Upgrade pip
echo "⬆️  Upgrading pip..."
./venv/bin/pip install --upgrade pip setuptools wheel > /dev/null 2>&1

# Install chatterbox-tts package
if ! ./venv/bin/pip show chatterbox-tts > /dev/null 2>&1; then
    echo "📥 Installing chatterbox-tts package..."
    ./venv/bin/pip install chatterbox-tts > /dev/null 2>&1
    echo "✓ Installed chatterbox-tts"
else
    echo "✓ chatterbox-tts already installed"
fi

# Create server script if not exists
if [ ! -f "server.py" ]; then
    cat > server.py << 'PYSERVER'
#!/usr/bin/env python3
"""Simple Chatterbox TTS server compatible with OpenAI API"""
import os
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
import uvicorn
from chatterbox.tts_turbo import ChatterboxTurboTTS
import io
import soundfile as sf

app = FastAPI(title="Chatterbox TTS Server")
model = None

@app.on_event("startup")
async def load_model():
    global model
    print("Loading Chatterbox Turbo model...")
    model = ChatterboxTurboTTS.from_pretrained(device="cpu")
    print("Model loaded!")

@app.get("/")
async def root():
    return {"status": "ok", "model": "chatterbox-turbo"}

@app.post("/v1/audio/speech")
async def generate_speech(
    input: str,
    model_name: str = "tts-1",
    voice: str = "default",
    response_format: str = "mp3"
):
    """OpenAI-compatible TTS endpoint"""
    global model

    if not input:
        raise HTTPException(status_code=400, detail="No input text provided")

    # Generate audio
    wav = model.generate(input)

    # Convert to bytes
    buffer = io.BytesIO()
    sf.write(buffer, wav.squeeze().cpu().numpy(), model.sr, format='WAV')
    buffer.seek(0)

    return Response(content=buffer.read(), media_type="audio/wav")

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8004)
PYSERVER
    chmod +x server.py
fi

# Install server dependencies
echo "📥 Installing server dependencies..."
./venv/bin/pip install fastapi uvicorn soundfile > /dev/null 2>&1

echo "✅ Chatterbox provider installed"
echo "   Model will download on first start (~2GB)"
