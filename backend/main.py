from fastapi import FastAPI, File, UploadFile
from typing import List
from photoquality import (
    read_image_bytes,
    calculate_score,
    enhance_image
)
import base64
import cv2

app = FastAPI()

@app.post("/upload-images")
async def upload_images(files: List[UploadFile] = File(...)):
    results = []
    duplicate_hashes = set()

    for file in files:
        contents = await file.read()
        img = read_image_bytes(contents)

        score, img_hash = calculate_score(img, duplicate_hashes)
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
    img = read_image_bytes(contents)

    enhanced_img = enhance_image(img)

    _, buffer = cv2.imencode('.jpg', enhanced_img)
    enhanced_base64 = base64.b64encode(buffer).decode("utf-8")

    return {"enhanced": enhanced_base64}
