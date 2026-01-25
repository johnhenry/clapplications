#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📥 Installing Qwen3-TTS provider..."

# Check for Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Error: python3 is not installed"
    echo "   Please install Python 3.8+ and try again"
    exit 1
fi

# Create qwen3-tts directory if not exists
if [ ! -d "$PROVIDER_DIR/qwen3-tts" ]; then
    mkdir -p "$PROVIDER_DIR/qwen3-tts"
fi

cd "$PROVIDER_DIR/qwen3-tts"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    # Use Python 3.10-3.12 for best compatibility
    if command -v python3.11 &> /dev/null; then
        python3.11 -m venv venv
    elif command -v python3.12 &> /dev/null; then
        python3.12 -m venv venv
    elif command -v python3.10 &> /dev/null; then
        python3.10 -m venv venv
    else
        echo "⚠️  Warning: Python 3.10-3.12 not found, using default python3"
        python3 -m venv venv
    fi
    echo "✓ Created virtual environment"
else
    echo "✓ Virtual environment already exists"
fi

# Upgrade pip
echo "⬆️  Upgrading pip..."
./venv/bin/pip install --upgrade pip setuptools wheel > /dev/null 2>&1

# Install qwen-tts and dependencies
if ! ./venv/bin/pip show qwen-tts > /dev/null 2>&1; then
    echo "📥 Installing Qwen3-TTS and dependencies..."
    echo "   This may take a few minutes..."

    # Install PyTorch first (CPU by default, CUDA users can reinstall with CUDA)
    ./venv/bin/pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu 2>&1 | grep -v "already satisfied" || true

    # Install qwen-tts
    ./venv/bin/pip install qwen-tts 2>&1 | grep -v "already satisfied" || true

    echo "✓ Installed Qwen3-TTS"
else
    echo "✓ Qwen3-TTS already installed"
fi

# Try to install flash-attn for better performance (optional, may fail on some systems)
echo "📥 Attempting to install flash-attn (optional, for better GPU performance)..."
if ./venv/bin/pip install flash-attn --no-build-isolation 2>/dev/null; then
    echo "✓ Installed flash-attn"
else
    echo "ℹ️  flash-attn not available (this is fine, will use standard attention)"
fi

# Install server dependencies
echo "📥 Installing server dependencies..."
./venv/bin/pip install fastapi uvicorn pydantic soundfile > /dev/null 2>&1

# Create server script
cat > server.py << 'PYSERVER'
#!/usr/bin/env python3
"""Qwen3-TTS server compatible with OpenAI API"""
import os
import io
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
import uvicorn
import soundfile as sf

# Global model instance
tts_model = None
SAMPLE_RATE = 24000  # Qwen3-TTS outputs 24kHz audio

# Voice mapping: OpenAI voice names to Qwen3-TTS speakers
VOICE_MAP = {
    "alloy": "Chelsie",
    "echo": "Ethan",
    "fable": "Aria",
    "onyx": "Leo",
    "nova": "Isabella",
    "shimmer": "Sophia",
    "default": "Chelsie",
}

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, cleanup on shutdown"""
    global tts_model, SAMPLE_RATE
    print("Loading Qwen3-TTS model...")
    print("This may take 5-10 minutes on first run as the model downloads (~3GB)...")

    from qwen_tts import Qwen3TTSModel

    # Detect device
    device = "cpu"
    try:
        import torch
        if torch.cuda.is_available():
            device = "cuda:0"
            print(f"Using CUDA GPU")
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            device = "mps"
            print(f"Using Apple Metal GPU")
        else:
            print(f"Using CPU (no GPU detected)")
    except Exception as e:
        print(f"GPU detection failed, using CPU: {e}")

    # Load model - use smaller 0.6B variant for lower VRAM, or 1.7B for quality
    model_name = os.environ.get("QWEN_TTS_MODEL", "Qwen/Qwen3-TTS-12Hz-0.6B")
    print(f"Loading model: {model_name}")

    tts_model = Qwen3TTSModel.from_pretrained(
        model_name,
        device=device
    )
    SAMPLE_RATE = tts_model.sample_rate if hasattr(tts_model, 'sample_rate') else 24000
    print(f"Model loaded! Sample rate: {SAMPLE_RATE}")
    yield
    # Cleanup on shutdown
    tts_model = None

app = FastAPI(title="Qwen3-TTS Server", lifespan=lifespan)

class TTSRequest(BaseModel):
    """OpenAI-compatible TTS request"""
    input: str
    model: str = "tts-1"
    voice: str = "default"
    response_format: str = "wav"
    speed: float = 1.0

@app.get("/")
async def root():
    return {"status": "ok", "model": "qwen3-tts"}

@app.get("/health")
async def health():
    return {"status": "healthy", "model": "qwen3-tts"}

@app.post("/v1/audio/speech")
async def generate_speech(request: TTSRequest):
    """OpenAI-compatible TTS endpoint"""
    global tts_model

    if tts_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    if not request.input:
        raise HTTPException(status_code=400, detail="No input text provided")

    # Map voice name to Qwen3-TTS speaker
    speaker = VOICE_MAP.get(request.voice.lower(), VOICE_MAP["default"])

    try:
        # Generate audio with Qwen3-TTS
        # The API expects text and speaker name
        audio = tts_model.generate(
            text=request.input,
            speaker=speaker
        )

        # Convert to numpy array if needed
        if hasattr(audio, 'cpu'):
            audio_np = audio.squeeze().cpu().numpy()
        else:
            audio_np = audio

        # Convert to bytes
        buffer = io.BytesIO()
        sf.write(buffer, audio_np, SAMPLE_RATE, format='WAV')
        buffer.seek(0)

        return Response(content=buffer.read(), media_type="audio/wav")

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {str(e)}")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8004))
    uvicorn.run(app, host="127.0.0.1", port=port)
PYSERVER

chmod +x server.py

echo "✅ Qwen3-TTS provider installed"
echo "   Model will download on first start (~3GB)"
echo "   No HuggingFace authentication required (public model)"
