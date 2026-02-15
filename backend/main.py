from fastapi import FastAPI, File, UploadFile
import os
from typing import List
from photoquality import final_score

app = FastAPI()
UPLOAD_DIR = "temp_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/")
def home():
    return {"message": "Backend running successfully"}

@app.post("/upload-images")
async def upload_images(files: List[UploadFile] = File(...)):
    results = []
    duplicate_hashes = set()

    for file in files:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        contents = await file.read()

        with open(file_path, "wb") as f:
            f.write(contents)

        try:
            score, img_hash = final_score(file_path, duplicate_hashes)
            results.append({
                "filename": file.filename,
                "score": round(float(score), 2)
            })
            duplicate_hashes.add(img_hash)  # Only here
        except Exception as e:
            results.append({
                "filename": file.filename,
                "score": 0,
                "error": str(e)
            })
        finally:
            if os.path.exists(file_path):
                os.remove(file_path)

    results.sort(key=lambda x: x["score"], reverse=True)
    return {"results": results}
