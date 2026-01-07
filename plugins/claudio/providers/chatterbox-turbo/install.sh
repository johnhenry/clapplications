#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📥 Installing Chatterbox TTS provider..."

# Check for Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Error: python3 is not installed"
    echo "   Please install Python 3.8+ and try again"
    exit 1
fi

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
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
import uvicorn
from chatterbox.tts_turbo import ChatterboxTurboTTS
import io
import soundfile as sf

# Global model instance
model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, cleanup on shutdown"""
    global model
    print("Loading Chatterbox Turbo model...")
    model = ChatterboxTurboTTS.from_pretrained(device="cpu")
    print("Model loaded!")
    yield
    # Cleanup on shutdown (if needed)
    model = None

app = FastAPI(title="Chatterbox TTS Server", lifespan=lifespan)

class TTSRequest(BaseModel):
    """OpenAI-compatible TTS request"""
    input: str
    model: str = "tts-1"
    voice: str = "default"
    response_format: str = "mp3"

@app.get("/")
async def root():
    return {"status": "ok", "model": "chatterbox-turbo"}

@app.post("/v1/audio/speech")
async def generate_speech(request: TTSRequest):
    """OpenAI-compatible TTS endpoint"""
    global model

    if not request.input:
        raise HTTPException(status_code=400, detail="No input text provided")

    # Generate audio
    wav = model.generate(request.input)

    # Convert to bytes
    buffer = io.BytesIO()
    sf.write(buffer, wav.squeeze().cpu().numpy(), model.sr, format='WAV')
    buffer.seek(0)

    return Response(content=buffer.read(), media_type="audio/wav")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8004))
    uvicorn.run(app, host="127.0.0.1", port=port)
PYSERVER
    chmod +x server.py
fi

# Install server dependencies
echo "📥 Installing server dependencies..."
./venv/bin/pip install fastapi uvicorn pydantic soundfile > /dev/null 2>&1

echo "✅ Chatterbox provider installed"
echo "   Model will download on first start (~2GB)"
