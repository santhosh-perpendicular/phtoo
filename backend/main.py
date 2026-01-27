from fastapi import FastAPI, File, UploadFile
from photoquality import final_score
import os
from typing import List

app = FastAPI()

UPLOAD_DIR = "temp_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.get("/")
def home():
    return {"message": "Backend running successfully"}


@app.post("/upload-images")
async def upload_images(files: List[UploadFile] = File(...)):
    results = []
    duplicate_hashes = set()   # reset every batch

    for file in files:
        # Save image
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        contents = await file.read()

        with open(file_path, "wb") as f:
            f.write(contents)

        try:
            # Get score and hash from your AI logic
            score, img_hash = final_score(file_path, duplicate_hashes)

            # Save result
            results.append({
                "filename": file.filename,
                "score": round(float(score), 2)
            })

            # Store hash to detect duplicates
            duplicate_hashes.add(img_hash)

        except Exception as e:
            results.append({
                "filename": file.filename,
                "score": 0,
                "error": str(e)
            })

        finally:
            # Delete temp file
            if os.path.exists(file_path):
                os.remove(file_path)

    # Sort by best score first
    results.sort(key=lambda x: x["score"], reverse=True)

    return {"results": results}
