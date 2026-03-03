"""
main.py — HACKX FastAPI Backend
Features: Auth · SQLite DB · AI Captions · Organized Folders · Precious Photo Guard
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
import asyncio
import base64
import cv2
import os
import json
import hashlib
import secrets
import time
from groq import Groq
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor

from photoquality import read_image_bytes, calculate_score, enhance_image_basic
from database import (
    init_db, authenticate, create_user,
    get_folders, create_folder, delete_folder,
    save_photo, get_photos, delete_photo, get_photo,
    set_precious, move_photo
)

load_dotenv()

groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
app = FastAPI(title="HACKX API")
executor = ThreadPoolExecutor(max_workers=4)

# ── In-memory session store (token → user dict) ──────────────────────
# For production replace with Redis or JWT
_sessions: dict[str, dict] = {}

# ── CORS ─────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Startup ──────────────────────────────────────────────────────────
@app.on_event("startup")
def startup():
    init_db()


# ── Auth helpers ─────────────────────────────────────────────────────
def issue_token(user: dict) -> str:
    token = secrets.token_hex(32)
    _sessions[token] = user
    return token


def get_current_user(authorization: str = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split(" ", 1)[1]
    user = _sessions.get(token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user


# ═══════════════════════════════════════════════════════════════════════
#  1. AUTH ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════

class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str
    password: str


@app.post("/auth/login")
def login(req: LoginRequest):
    # Check if username exists at all
    conn = __import__('database').get_conn()
    row = conn.execute(
        "SELECT * FROM users WHERE username = ?", (req.username.strip(),)
    ).fetchone()
    conn.close()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Account not found. Please register first."
        )

    # Username exists — now check password
    user = authenticate(req.username.strip(), req.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Incorrect password. Please try again."
        )

    token = issue_token(user)
    return {"token": token, "user": user}


@app.post("/auth/register")
def register(req: RegisterRequest):
    username = req.username.strip()
    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters.")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters.")

    # Check if already exists
    conn = __import__('database').get_conn()
    row = conn.execute(
        "SELECT id FROM users WHERE username = ?", (username,)
    ).fetchone()
    conn.close()
    if row:
        raise HTTPException(status_code=409, detail="Username already taken. Please choose another.")

    user = create_user(username, req.password)
    if not user:
        raise HTTPException(status_code=500, detail="Registration failed. Try again.")
    token = issue_token(user)
    return {"token": token, "user": user}


@app.post("/auth/logout")
def logout(authorization: str = Header(None)):
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1]
        _sessions.pop(token, None)
    return {"ok": True}


@app.get("/auth/me")
def me(user: dict = Depends(get_current_user)):
    return user


# ═══════════════════════════════════════════════════════════════════════
#  2. FOLDER ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════

class FolderCreate(BaseModel):
    name: str


@app.get("/folders")
def list_folders(user: dict = Depends(get_current_user)):
    return get_folders(user["id"])


@app.post("/folders")
def new_folder(req: FolderCreate, user: dict = Depends(get_current_user)):
    folder = create_folder(user["id"], req.name.strip())
    if not folder:
        raise HTTPException(status_code=409, detail="Folder already exists")
    return folder


@app.delete("/folders/{folder_id}")
def remove_folder(folder_id: int, user: dict = Depends(get_current_user)):
    if not delete_folder(folder_id, user["id"]):
        raise HTTPException(status_code=404, detail="Folder not found")
    return {"ok": True}


# ═══════════════════════════════════════════════════════════════════════
#  3. PHOTO ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════

def _run_cv(contents, duplicate_hashes):
    img = read_image_bytes(contents)
    if img is None:
        return None, None, None
    score, img_hash, breakdown = calculate_score(img, duplicate_hashes)
    return score, img_hash, breakdown


def _generate_caption(b64: str) -> str:
    """Call Groq vision to produce a short photo caption."""
    try:
        response = groq_client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[{
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
                    },
                    {
                        "type": "text",
                        "text": (
                            "Write a single short, descriptive caption for this photo "
                            "(max 15 words). No quotes, no extra text."
                        )
                    }
                ]
            }],
            max_tokens=40,
        )
        return response.choices[0].message.content.strip().strip('"')
    except Exception:
        return "Photo"


def _safe_breakdown(breakdown: dict) -> dict:
    """Convert all numpy float32 values to plain Python float so json.dumps works."""
    return {k: float(v) for k, v in (breakdown or {}).items()}


def _auto_folder_name(score: float, session_label: str) -> str:
    """6-bucket score → folder name with session prefix."""
    if score >= 90:
        return f"[{session_label}] 🏆 Excellent (90-100)"
    elif score >= 80:
        return f"[{session_label}] ⭐ Great (80-89)"
    elif score >= 70:
        return f"[{session_label}] ✅ Good (70-79)"
    elif score >= 60:
        return f"[{session_label}] 📷 Average (60-69)"
    elif score >= 50:
        return f"[{session_label}] ⚠️ Below Average (50-59)"
    else:
        return f"[{session_label}] 🗑 Poor (below 50)"


def _get_or_create_folder(user_id: int, name: str) -> int:
    """Return existing folder id or create it and return the new id."""
    folders = get_folders(user_id)
    for f in folders:
        if f["name"] == name:
            return f["id"]
    folder = create_folder(user_id, name)
    return folder["id"]


@app.post("/upload-images")
async def upload_images(
    files: List[UploadFile] = File(...),
    folder_id: Optional[int] = None,          # manual folder override
    precious_indexes: Optional[str] = None,   # comma-separated e.g. "0,2,4"
    user: dict = Depends(get_current_user),
):
    # ── Parse precious indexes ──────────────────────────────────────────
    precious_set: set[int] = set()
    if precious_indexes:
        for part in precious_indexes.split(','):
            part = part.strip()
            if part.isdigit():
                precious_set.add(int(part))

    # ── One session label for this entire upload batch ─────────────────
    from datetime import datetime as _dt
    # Count existing sessions for this user to get session number
    existing = get_folders(user["id"])
    # Count folders that look like session folders (start with "[")
    session_num = len([f for f in existing if f["name"].startswith("[")]) 
    # Find the highest session number used
    import re as _re
    nums = []
    for f in existing:
        m = _re.match(r'\[S(\d+)', f["name"])
        if m:
            nums.append(int(m.group(1)))
    next_num = (max(nums) + 1) if nums else 1
    session_label = f"S{next_num} · {_dt.now().strftime('%d %b %H:%M')}"

    results = []
    duplicate_hashes: set = set()
    loop = asyncio.get_event_loop()
    # Cache folder ids within this session so we don't re-query DB for each photo
    session_folder_cache: dict[str, int] = {}

    for idx, file in enumerate(files):
        contents = await file.read()
        is_precious = idx in precious_set

        # ── Save file to disk for later thumbnail display ──────────────
        upload_dir = os.path.join(os.path.dirname(__file__), "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        safe_name = f"{int(asyncio.get_event_loop().time() * 1000)}_{file.filename}"
        filepath = os.path.join(upload_dir, safe_name)
        with open(filepath, "wb") as f_out:
            f_out.write(contents)

        score, img_hash, breakdown = await loop.run_in_executor(
            executor, _run_cv, contents, duplicate_hashes.copy()
        )

        if score is None:
            results.append({
                "filename": file.filename,
                "score": 0.0,
                "caption": "",
                "error": "Could not decode image",
                "precious": is_precious,
                "show_delete": False,
                "folder": None,
            })
            continue

        duplicate_hashes.add(img_hash)

        # ── AI Caption ─────────────────────────────────────────────────
        b64 = base64.b64encode(contents).decode()
        caption = await loop.run_in_executor(executor, _generate_caption, b64)

        score_val = round(float(score), 2)

        # ── Auto-organize into session-specific folder ─────────────────
        if folder_id is None:
            auto_name = _auto_folder_name(score_val, session_label)
            if auto_name in session_folder_cache:
                target_folder_id = session_folder_cache[auto_name]
            else:
                target_folder_id = await loop.run_in_executor(
                    executor, _get_or_create_folder, user["id"], auto_name
                )
                session_folder_cache[auto_name] = target_folder_id
            folder_label = auto_name
        else:
            target_folder_id = folder_id
            folder_label = None

        # ── Fix float32 → float before json.dumps ──────────────────────
        safe_bd = _safe_breakdown(breakdown)

        photo_id = save_photo(
            user_id=user["id"],
            folder_id=target_folder_id,
            filename=file.filename,
            filepath=filepath,
            score=score_val,
            caption=caption,
            is_precious=is_precious,
            breakdown=json.dumps(safe_bd),
        )

        show_delete = (score_val < 65) and (not is_precious)

        results.append({
            "id": photo_id,
            "filename": file.filename,
            "filepath": filepath,
            "score": score_val,
            "caption": caption,
            "precious": is_precious,
            "show_delete": show_delete,
            "folder": folder_label,
            "breakdown": safe_bd,
        })

    results.sort(key=lambda x: x["score"], reverse=True)
    return {"results": results}


@app.get("/photos")
def list_photos(
    folder_id: Optional[int] = None,
    user: dict = Depends(get_current_user),
):
    return get_photos(user["id"], folder_id)


@app.delete("/photos/{photo_id}")
def remove_photo(
    photo_id: int,
    force: bool = False,
    user: dict = Depends(get_current_user),
):
    """
    Delete a photo.
    Precious photos are blocked unless force=true.
    """
    photo = get_photo(photo_id, user["id"])
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    if photo["is_precious"] and not force:
        raise HTTPException(
            status_code=403,
            detail="This photo is marked as precious. Use force=true to delete."
        )
    delete_photo(photo_id, user["id"])
    return {"ok": True}


@app.patch("/photos/{photo_id}/precious")
def toggle_precious(
    photo_id: int,
    precious: bool,
    user: dict = Depends(get_current_user),
):
    """Mark / unmark a photo as precious."""
    ok = set_precious(photo_id, user["id"], precious)
    if not ok:
        raise HTTPException(status_code=404, detail="Photo not found")
    return {"ok": True, "precious": precious}


@app.patch("/photos/{photo_id}/move")
def move_to_folder(
    photo_id: int,
    folder_id: Optional[int] = None,
    user: dict = Depends(get_current_user),
):
    """Move a photo to a different folder (or None = root)."""
    ok = move_photo(photo_id, user["id"], folder_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Photo not found")
    return {"ok": True}


# ═══════════════════════════════════════════════════════════════════════
#  4. ENHANCE + ANALYZE  (unchanged logic, added auth)
# ═══════════════════════════════════════════════════════════════════════

@app.post("/enhance-image")
async def enhance_selected_image(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    contents = await file.read()
    b64 = base64.b64encode(contents).decode("utf-8")

    try:
        response = groq_client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image_url",
                     "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                    {"type": "text",
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
- clahe: true if image looks flat or low contrast"""}
                ]
            }],
            response_format={"type": "json_object"},
        )
        params = json.loads(response.choices[0].message.content.strip())
    except Exception:
        params = {"brightness": 10, "contrast": 1.2, "sharpen": True,
                  "denoise": True, "clahe": True}

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
        img = cv2.convertScaleAbs(img,
                                  alpha=params.get("contrast", 1.0),
                                  beta=params.get("brightness", 0))
        if params.get("sharpen"):
            import numpy as np
            kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
            img = cv2.filter2D(img, -1, kernel)
        _, buffer = cv2.imencode('.jpg', img)
        return base64.b64encode(buffer).decode("utf-8")

    loop = asyncio.get_event_loop()
    enhanced_b64 = await loop.run_in_executor(executor, apply_enhancements)
    return {"enhanced": enhanced_b64, "method": "ai"}


@app.post("/analyze-image")
async def analyze_image(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    contents = await file.read()
    b64 = base64.b64encode(contents).decode("utf-8")
    try:
        response = groq_client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image_url",
                     "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                    {"type": "text",
                     "text": """You are a professional photo analyst. Analyze this photo and give a short structured report.
Return ONLY this JSON format, no extra text:
{
  "overall": "one sentence summary",
  "issues": ["issue1", "issue2", "issue3"],
  "strengths": ["strength1", "strength2"],
  "tip": "one actionable improvement tip"
}"""}
                ]
            }],
            response_format={"type": "json_object"},
        )
        data = json.loads(response.choices[0].message.content.strip())
        return {"analysis": data, "status": "success"}
    except Exception as e:
        return {
            "analysis": {
                "overall": "Analysis unavailable",
                "issues": [], "strengths": [],
                "tip": str(e)
            },
            "status": "error"
        }