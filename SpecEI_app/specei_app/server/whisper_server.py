import os
import shutil
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel
import uvicorn

app = FastAPI(title="SpecEI Local Whisper Server")

# Enable CORS for web/mobile access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
# "tiny", "base", "small", "medium", "large-v3"
# Use "tiny" or "base" for CPU. Use "medium" or larger if you have a GPU.
MODEL_SIZE = "base" 
DEVICE = "auto" # "cuda" if GPU available, else "cpu"
COMPUTE_TYPE = "int8" # "float16" for GPU, "int8" for CPU

print(f"Loading Whisper model: {MODEL_SIZE} on {DEVICE}...")
try:
    model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
    print("✅ Model loaded successfully!")
except Exception as e:
    print(f"❌ Error loading model: {e}")
    print("Using CPU fallback configuration...")
    model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")

@app.get("/")
def health_check():
    return {"status": "running", "model": MODEL_SIZE}

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    print(f"🎤 Received audio file: {file.filename}")
    
    # Save uploaded file temporarily
    temp_filename = f"temp_{file.filename}"
    try:
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Transcribe
        print("📝 Transcribing...")
        segments, info = model.transcribe(temp_filename, beam_size=5)
        
        transcription = " ".join([segment.text for segment in segments]).strip()
        print(f"✅ Result: {transcription}")
        
        return {
            "text": transcription,
            "language": info.language,
            "probability": info.language_probability
        }
        
    except Exception as e:
        print(f"❌ Error during transcription: {e}")
        raise HTTPException(status_code=500, detail=str(e))
        
    finally:
        # Cleanup temp file
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

if __name__ == "__main__":
    print("🚀 Starting Whisper Server on http://0.0.0.0:8000")
    print("📱 Make sure your Flutter app is on the same network or use 'localhost' if running on emulator/simulator")
    uvicorn.run(app, host="0.0.0.0", port=8000)
