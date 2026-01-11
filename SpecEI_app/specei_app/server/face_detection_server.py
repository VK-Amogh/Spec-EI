# Face Detection Server for SpecEI
# Uses OpenCV with Haar Cascades for real-time face detection
# Runs on http://localhost:8001

import os
import cv2
import numpy as np
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import base64

app = FastAPI(title="SpecEI Face Detection Server")

# Enable CORS for web/mobile access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load OpenCV's pre-trained face detector (Haar Cascade)
# This is fast and works well for real-time detection
CASCADE_PATH = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
face_cascade = cv2.CascadeClassifier(CASCADE_PATH)

# Also load eye cascade for additional feature detection
EYE_CASCADE_PATH = cv2.data.haarcascades + "haarcascade_eye.xml"
eye_cascade = cv2.CascadeClassifier(EYE_CASCADE_PATH)

print(f"✅ Face detector loaded: {CASCADE_PATH}")

@app.get("/")
def health_check():
    return {"status": "running", "service": "face_detection"}

@app.post("/detect")
async def detect_faces(file: UploadFile = File(...)):
    """
    Detect faces in an uploaded image.
    Returns bounding boxes and face count.
    """
    try:
        # Read image bytes
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Could not decode image")
        
        # Convert to grayscale for detection
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect faces
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30),
            flags=cv2.CASCADE_SCALE_IMAGE
        )
        
        # Build response with face data
        face_data = []
        for i, (x, y, w, h) in enumerate(faces):
            # Get face region for eye detection
            roi_gray = gray[y:y+h, x:x+w]
            eyes = eye_cascade.detectMultiScale(roi_gray)
            
            face_info = {
                "id": i + 1,
                "x": int(x),
                "y": int(y),
                "width": int(w),
                "height": int(h),
                "confidence": 0.85,  # Haar doesn't give confidence, using default
                "eyes_detected": len(eyes),
            }
            face_data.append(face_info)
        
        return JSONResponse({
            "face_count": len(faces),
            "faces": face_data,
            "image_width": img.shape[1],
            "image_height": img.shape[0],
        })
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/detect_base64")
async def detect_faces_base64(data: dict):
    """
    Detect faces from base64 encoded image.
    Useful for sending frames from web camera.
    """
    try:
        image_data = data.get("image")
        if not image_data:
            raise HTTPException(status_code=400, detail="No image data provided")
        
        # Remove data URL prefix if present
        if "," in image_data:
            image_data = image_data.split(",")[1]
        
        # Decode base64
        img_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Could not decode image")
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect faces (optimized for speed)
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.2,  # Faster but less accurate
            minNeighbors=4,
            minSize=(50, 50),
        )
        
        face_data = []
        for i, (x, y, w, h) in enumerate(faces):
            face_data.append({
                "id": i + 1,
                "x": int(x),
                "y": int(y),
                "width": int(w),
                "height": int(h),
            })
        
        return {
            "face_count": len(faces),
            "faces": face_data,
        }
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    print("🚀 Starting Face Detection Server on http://0.0.0.0:8001")
    print("📱 Endpoints:")
    print("   POST /detect - Upload image file")
    print("   POST /detect_base64 - Send base64 image")
    uvicorn.run(app, host="0.0.0.0", port=8001)
