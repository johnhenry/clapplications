#!/bin/bash
set -e

PROVIDER_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📥 Installing SenseVoice STT provider..."

# Check for Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Error: python3 is not installed"
    echo "   Please install Python 3.8+ and try again"
    exit 1
fi

# Create sensevoice directory if not exists
if [ ! -d "$PROVIDER_DIR/sensevoice" ]; then
    mkdir -p "$PROVIDER_DIR/sensevoice"
fi

cd "$PROVIDER_DIR/sensevoice"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    # Use Python 3.10-3.12 for best compatibility with funasr
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

# Install funasr and dependencies
if ! ./venv/bin/pip show funasr > /dev/null 2>&1; then
    echo "📥 Installing FunASR and dependencies..."
    echo "   This may take a few minutes..."

    # Install PyTorch first (CPU by default, CUDA users can reinstall with CUDA)
    ./venv/bin/pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu 2>&1 | grep -v "already satisfied" || true

    # Install funasr
    ./venv/bin/pip install funasr 2>&1 | grep -v "already satisfied" || true

    echo "✓ Installed FunASR"
else
    echo "✓ FunASR already installed"
fi

# Install server dependencies
echo "📥 Installing server dependencies..."
./venv/bin/pip install fastapi uvicorn python-multipart > /dev/null 2>&1

# Create server script
cat > server.py << 'PYSERVER'
#!/usr/bin/env python3
"""SenseVoice STT server compatible with OpenAI API"""
import os
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

# Global model instance
stt_model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, cleanup on shutdown"""
    global stt_model
    print("Loading SenseVoice model...")
    print("This may take a few minutes on first run as the model downloads...")

    from funasr import AutoModel

    # Detect device
    device = "cpu"
    try:
        import torch
        if torch.cuda.is_available():
            device = "cuda:0"
            print("Using CUDA GPU")
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            # Note: FunASR may have limited MPS support
            device = "cpu"
            print("Apple Silicon detected, using CPU (MPS has limited FunASR support)")
        else:
            print("Using CPU (no GPU detected)")
    except Exception as e:
        print(f"GPU detection failed, using CPU: {e}")

    # Load SenseVoice model with VAD for better segmentation
    stt_model = AutoModel(
        model="iic/SenseVoiceSmall",
        vad_model="fsmn-vad",
        vad_kwargs={"max_single_segment_time": 30000},
        device=device,
        disable_update=True
    )
    print("Model loaded!")
    yield
    # Cleanup on shutdown
    stt_model = None

app = FastAPI(title="SenseVoice STT Server", lifespan=lifespan)

@app.get("/")
async def root():
    return {"status": "ok", "model": "sensevoice"}

@app.get("/health")
async def health():
    return {"status": "healthy", "model": "iic/SenseVoiceSmall"}

@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form(default="sensevoice"),
    language: str = Form(default="auto"),
    response_format: str = Form(default="json")
):
    """OpenAI-compatible transcription endpoint"""
    global stt_model

    if stt_model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    # Save uploaded file temporarily
    suffix = Path(file.filename).suffix if file.filename else ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        # Import postprocessing utility
        from funasr.utils.postprocess_utils import rich_transcription_postprocess

        # Run transcription
        result = stt_model.generate(
            input=tmp_path,
            cache={},
            language=language if language != "auto" else "auto",
            use_itn=True,
            batch_size_s=60,
            merge_vad=True,
            merge_length_s=15
        )

        # Extract and clean text from result
        if result and len(result) > 0:
            raw_text = result[0].get("text", "")
            # Use rich_transcription_postprocess to clean up output
            text = rich_transcription_postprocess(raw_text)
        else:
            text = ""

        # Return in OpenAI format
        if response_format == "text":
            return text
        elif response_format == "verbose_json":
            return JSONResponse({
                "text": text,
                "language": language,
                "model": "sensevoice"
            })
        else:
            return JSONResponse({"text": text})

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        # Clean up temp file
        try:
            os.unlink(tmp_path)
        except:
            pass

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 2022))
    uvicorn.run(app, host="127.0.0.1", port=port)
PYSERVER

chmod +x server.py

echo "✅ SenseVoice provider installed"
echo "   Model will download on first start (~500MB)"
