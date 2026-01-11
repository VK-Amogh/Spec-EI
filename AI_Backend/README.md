# SpecEI AI Backend

Local AI services for the SpecEI Flutter app, providing speech-to-text transcription via OpenAI Whisper.

## Quick Start

### 1. Prerequisites
- **Python 3.10+** - [Download](https://python.org)
- **FFmpeg** - Auto-installed via setup script, or [download manually](https://ffmpeg.org)
- **GPU (Optional)** - NVIDIA GPU with CUDA for faster transcription

### 2. Setup
```powershell
cd AI_Backend
.\setup.ps1
```

This will:
- Create a Python virtual environment
- Install PyTorch (with CUDA if available)
- Install OpenAI Whisper and dependencies
- Download the Whisper `base` model (~140MB)

### 3. Start the Server
```powershell
.\start_server.ps1
```

Server runs at: `http://localhost:8000`

### 4. Test the Server
```powershell
# Health check
Invoke-RestMethod http://localhost:8000/

# Test transcription (replace with your audio file)
curl -X POST http://localhost:8000/transcribe -F "file=@test.wav"
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check, returns model info |
| `/health` | GET | Simple health check |
| `/transcribe` | POST | Transcribe audio file |
| `/transcribe-with-timestamps` | POST | Transcribe with word timestamps |

## Configuration

Set environment variables before starting:

```powershell
$env:WHISPER_MODEL = "base"   # Options: tiny, base, small, medium, large-v3
$env:WHISPER_DEVICE = "cuda"  # Options: cuda, cpu
.\start_server.ps1
```

### Model Sizes

| Model | Size | VRAM | Speed | Accuracy |
|-------|------|------|-------|----------|
| tiny | 39MB | ~1GB | Fastest | Basic |
| base | 142MB | ~1GB | Fast | Good |
| small | 483MB | ~2GB | Medium | Better |
| medium | 1.5GB | ~5GB | Slow | Great |
| large-v3 | 3GB | ~10GB | Slowest | Best |

## Flutter Integration

The Flutter app's `local_whisper_service.dart` is already configured to use this server.

Make sure your `env_config.dart` has:
```dart
static const String localWhisperUrl = 'http://localhost:8000/transcribe';
```

## Video LLaMA (Optional)

Video LLaMA requires:
- GPU with 24GB+ VRAM (RTX 3090/4090)
- ~14GB disk space for model weights

If hardware available, see `video_llama_server.py` for setup instructions.

## Troubleshooting

### "Model not found"
Run `setup.ps1` again to download the model.

### "CUDA out of memory"
Use a smaller model: `$env:WHISPER_MODEL = "tiny"`

### "FFmpeg not found"
Install manually: `winget install Gyan.FFmpeg`
