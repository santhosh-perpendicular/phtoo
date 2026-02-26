from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from typing import List
from photoquality import (
    read_image_bytes,
    calculate_score,
    enhance_image_basic
)
import asyncio
import base64
import cv2
import os
import json
from groq import Groq
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor

load_dotenv()

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

executor = ThreadPoolExecutor(max_workers=4)


def process_image(contents, duplicate_hashes):
    """Run blocking CV2 operations in a thread"""
    img = read_image_bytes(contents)
    if img is None:
        return None, None
    score, img_hash = calculate_score(img, duplicate_hashes)
    return score, img_hash


@app.post("/upload-images")
async def upload_images(files: List[UploadFile] = File(...)):
    results = []
    duplicate_hashes = set()

    for file in files:
        contents = await file.read()
        loop = asyncio.get_event_loop()

        # Run blocking CV2 + face detection in thread pool
        score, img_hash = await loop.run_in_executor(
            executor, process_image, contents, duplicate_hashes.copy()
        )

        if score is None:
            results.append({"filename": file.filename, "score": 0.0, "error": "Could not decode image"})
            continue

        duplicate_hashes.add(img_hash)
        results.append({
            "filename": file.filename,
            "score": round(float(score), 2)
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return {"results": results}


@app.post("/enhance-image")
async def enhance_selected_image(file: UploadFile = File(...)):
    contents = await file.read()
    b64 = base64.b64encode(contents).decode("utf-8")

    try:
        response = groq_client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
                        },
                        {
                            "type": "text",
                            "text": """Analyze this image and return ONLY this JSON, no extra text:
{
  "brightness": 0,
  "contrast": 1.0,
  "sharpen": false,
  "denoise": false,
  "clahe": false
}
Rules:
- brightness: integer between -80 and +80 (0 = no change)
- contrast: float between 0.5 and 2.0 (1.0 = no change)
- sharpen: true if image looks soft/blurry
- denoise: true if image looks grainy/noisy
- clahe: true if image looks flat or low contrast"""
                        }
                    ]
                }
            ],
            response_format={"type": "json_object"}
        )
        params = json.loads(response.choices[0].message.content.strip())

    except Exception:
        params = {
            "brightness": 10,
            "contrast": 1.2,
            "sharpen": True,
            "denoise": True,
            "clahe": True
        }

    def apply_enhancements():
        img = read_image_bytes(contents)

        if params.get("denoise"):
            img = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)

        if params.get("clahe"):
            lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
            l, a, b = cv2.split(lab)
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
            cl = clahe.apply(l)
            img = cv2.cvtColor(cv2.merge((cl, a, b)), cv2.COLOR_LAB2BGR)

        brightness = params.get("brightness", 0)
        contrast = params.get("contrast", 1.0)
        img = cv2.convertScaleAbs(img, alpha=contrast, beta=brightness)

        if params.get("sharpen"):
            kernel = cv2.UMat([[0, -1, 0],
                               [-1, 5, -1],
                               [0, -1, 0]])
            img = cv2.filter2D(img, -1, kernel)

        _, buffer = cv2.imencode('.jpg', img)
        return base64.b64encode(buffer).decode("utf-8")

    loop = asyncio.get_event_loop()
    enhanced_base64 = await loop.run_in_executor(executor, apply_enhancements)
    return {"enhanced": enhanced_base64, "method": "ai"}


@app.post("/analyze-image")
async def analyze_image(file: UploadFile = File(...)):
    contents = await file.read()
    b64 = base64.b64encode(contents).decode("utf-8")
    try:
        response = groq_client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
                        },
                        {
                            "type": "text",
                            "text": """You are a professional photo analyst. Analyze this photo and give a short structured report.
Return ONLY this JSON format, no extra text:
{
  "overall": "one sentence summary",
  "issues": ["issue1", "issue2", "issue3"],
  "strengths": ["strength1", "strength2"],
  "tip": "one actionable improvement tip"
}"""
                        }
                    ]
                }
            ],
            response_format={"type": "json_object"}
        )
        data = json.loads(response.choices[0].message.content.strip())
        return {"analysis": data, "status": "success"}
    except Exception as e:
        return {
            "analysis": {
                "overall": "Analysis unavailable",
                "issues": [],
                "strengths": [],
                "tip": str(e)
            },
            "status": "error"
        }