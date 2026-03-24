"""
main.py — HACKX FastAPI Backend
Features: Auth · SQLite DB · AI Captions · Organized Folders · Precious Photo Guard · Google OAuth
Registration now requires OTP email verification before account is created.
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Header
import smtplib
import random
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import asyncio
import base64
import cv2
import os
import json
import secrets
import httpx
from groq import Groq
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor
from photoquality import read_image_bytes, calculate_score, enhance_image_basic
from database import (
    init_db, authenticate, create_user,
    get_user_by_email, update_user_email,
    get_folders, create_folder, delete_folder,
    save_photo, get_photos, delete_photo, get_photo,
    set_precious, move_photo, email_exists
)
load_dotenv()
groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
app = FastAPI(title="HACKX API")
executor = ThreadPoolExecutor(max_workers=4)

# ── In-memory session store (token → user dict) ──────────────────────
_sessions: dict[str, dict] = {}

# ── OTP store for LOGIN (email → {otp, expires_at}) ──────────────────
_otp_store: dict[str, dict] = {}

# ── OTP store for REGISTRATION (email → {otp, expires_at, username, password}) ──
_reg_otp_store: dict[str, dict] = {}

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
#  EMAIL HELPER
# ═══════════════════════════════════════════════════════════════════════
def _send_otp_email(to_email: str, otp: str, subject_prefix: str = "Login"):
    gmail_user = os.getenv("GMAIL_USER")
    gmail_pass = os.getenv("GMAIL_APP_PASSWORD")
    if not gmail_user or not gmail_pass:
        raise Exception("GMAIL_USER or GMAIL_APP_PASSWORD not set in .env")
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"HACKX {subject_prefix} Code: {otp}"
    msg["From"]    = gmail_user
    msg["To"]      = to_email
    html = (
        '<html><body style="background:#080808;color:#F0F0F0;font-family:monospace;padding:40px">'
        '<div style="max-width:400px;margin:auto;background:#111;border:1px solid #2A2A2A;border-radius:8px;padding:32px">'
        '<div style="display:flex;align-items:center;margin-bottom:24px">'
        '<div style="background:#FFD600;width:36px;height:36px;border-radius:4px;margin-right:12px">'
        '<span style="font-size:20px">&#128247;</span></div>'
        '<span style="color:#F0F0F0;font-size:22px;font-weight:800;letter-spacing:6px">HACKX</span></div>'
        f'<p style="color:#666;font-size:12px;letter-spacing:1.5px">YOUR {subject_prefix.upper()} CODE</p>'
        '<div style="background:#181818;border:1px solid #FFD600;border-radius:6px;padding:24px;text-align:center;margin:16px 0">'
        f'<span style="color:#FFD600;font-size:36px;font-weight:800;letter-spacing:12px">{otp}</span></div>'
        '<p style="color:#666;font-size:11px">This code expires in <strong style="color:#F0F0F0">10 minutes</strong>.</p>'
        '<p style="color:#444;font-size:10px;margin-top:24px">If you did not request this, ignore this email.</p>'
        '</div></body></html>'
    )
    msg.attach(MIMEText(html, "html"))
    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(gmail_user, gmail_pass)
        server.sendmail(gmail_user, to_email, msg.as_string())

# ═══════════════════════════════════════════════════════════════════════
#  1. AUTH ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════
class LoginRequest(BaseModel):
    username: str
    password: str

class RegisterRequest(BaseModel):
    username: str
    password: str
    email: str  # Required for registration (needed for OTP)

class RegisterOtpSendRequest(BaseModel):
    username: str
    password: str
    email: str

class RegisterOtpVerifyRequest(BaseModel):
    email: str
    otp: str

class GoogleAuthRequest(BaseModel):
    id_token: str

@app.post("/auth/login")
def login(req: LoginRequest):
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
    user = authenticate(req.username.strip(), req.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Incorrect password. Please try again."
        )
    token = issue_token(user)
    return {"token": token, "user": user}


# ── Step 1: Send registration OTP ─────────────────────────────────────
@app.post("/auth/register/send-otp")
async def register_send_otp(req: RegisterOtpSendRequest):
    """
    Validate registration fields and send OTP to the email.
    The account is NOT created yet — only after OTP is verified.
    """
    username = req.username.strip()
    email    = req.email.strip().lower()

    # Basic validation
    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters.")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters.")
    if "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email address.")

    conn = __import__('database').get_conn()

    # Check username availability
    row = conn.execute("SELECT id FROM users WHERE username = ?", (username,)).fetchone()
    if row:
        conn.close()
        raise HTTPException(status_code=409, detail="Username already taken. Please choose another.")

    # Check email uniqueness — one email = one account, regardless of username
    row2 = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
    if row2:
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="This email is already registered. Please login instead."
        )
    conn.close()

    # Generate OTP and store pending registration
    otp      = str(random.randint(100000, 999999))
    expires  = datetime.utcnow() + timedelta(minutes=10)
    _reg_otp_store[email] = {
        "otp":        otp,
        "expires_at": expires,
        "username":   username,
        "password":   req.password,
    }

    # Send email
    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None, _send_otp_email, email, otp, "Registration"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send OTP email: {str(e)}")

    return {"ok": True, "message": f"OTP sent to {email}. Enter it to complete registration."}


# ── Step 2: Verify OTP and create account ─────────────────────────────
@app.post("/auth/register/verify-otp")
def register_verify_otp(req: RegisterOtpVerifyRequest):
    """
    Verify the registration OTP and create the user account.
    """
    email  = req.email.strip().lower()
    record = _reg_otp_store.get(email)

    if not record:
        raise HTTPException(status_code=400, detail="No pending registration found. Please start again.")
    if datetime.utcnow() > record["expires_at"]:
        _reg_otp_store.pop(email, None)
        raise HTTPException(status_code=400, detail="OTP expired. Please register again.")
    if req.otp.strip() != record["otp"]:
        raise HTTPException(status_code=401, detail="Incorrect OTP. Please try again.")

    # OTP valid — clear and create user
    _reg_otp_store.pop(email, None)

    # Final duplicate check before creating (race condition safety)
    if email_exists(email):
        raise HTTPException(
            status_code=409,
            detail="This email was registered while you were verifying. Please login."
        )

    user = create_user(record["username"], record["password"], email)
    if not user:
        raise HTTPException(
            status_code=409,
            detail="Username was taken while you were verifying. Please register again."
        )

    token = issue_token(user)
    return {"token": token, "user": user}


# ── Legacy /auth/register (kept for any direct API use) ───────────────
@app.post("/auth/register")
def register(req: RegisterRequest):
    """
    Direct registration without OTP — kept for backward compatibility.
    For the Flutter app, use /auth/register/send-otp + /auth/register/verify-otp instead.
    """
    username = req.username.strip()
    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters.")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters.")
    email = req.email.strip().lower() if req.email else None
    if email and "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email address.")

    conn = __import__('database').get_conn()
    row = conn.execute("SELECT id FROM users WHERE username = ?", (username,)).fetchone()
    if row:
        conn.close()
        raise HTTPException(status_code=409, detail="Username already taken.")
    if email:
        row2 = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if row2:
            conn.close()
            raise HTTPException(
                status_code=409,
                detail="This email is already registered. Please login instead."
            )
    conn.close()
    user = create_user(username, req.password, email)
    if not user:
        raise HTTPException(status_code=500, detail="Registration failed. Try again.")
    token = issue_token(user)
    return {"token": token, "user": user}


# ── Google OAuth ──────────────────────────────────────────────────────
@app.post("/auth/google")
async def google_login(req: GoogleAuthRequest):
    email = None
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": req.id_token},
            timeout=10,
        )
        if resp.status_code == 200:
            data = resp.json()
            email = data.get("email")
        if not email:
            resp2 = await client.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {req.id_token}"},
                timeout=10,
            )
            if resp2.status_code == 200:
                data = resp2.json()
                email = data.get("email")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid Google token. Please try again.")

    conn = __import__('database').get_conn()
    row = conn.execute(
        "SELECT id, username FROM users WHERE username = ? OR email = ?", (email, email)
    ).fetchone()
    conn.close()
    if row:
        user = {"id": row["id"], "username": row["username"]}
    else:
        rand_pass = secrets.token_hex(16)
        user = create_user(email, rand_pass, email)
        if not user:
            raise HTTPException(status_code=500, detail="Failed to create user account.")
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


# ── OTP (Login via email) ─────────────────────────────────────────────
class OtpRequest(BaseModel):
    email: str

class OtpVerify(BaseModel):
    email: str
    otp: str


@app.post("/auth/send-otp")
async def send_otp(req: OtpRequest):
    email = req.email.strip().lower()
    if "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email address.")
    conn = __import__('database').get_conn()
    row = conn.execute(
        "SELECT id FROM users WHERE email = ? OR username = ?", (email, email)
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="No account found with this email. Please register first.")
    otp     = str(random.randint(100000, 999999))
    expires = datetime.utcnow() + timedelta(minutes=10)
    _otp_store[email] = {"otp": otp, "expires_at": expires}
    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _send_otp_email, email, otp, "Login")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")
    return {"ok": True, "message": f"OTP sent to {email}"}


@app.post("/auth/verify-otp")
def verify_otp(req: OtpVerify):
    email  = req.email.strip().lower()
    record = _otp_store.get(email)
    if not record:
        raise HTTPException(status_code=400, detail="No OTP found. Please request a new one.")
    if datetime.utcnow() > record["expires_at"]:
        _otp_store.pop(email, None)
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")
    if req.otp.strip() != record["otp"]:
        raise HTTPException(status_code=401, detail="Incorrect OTP. Please try again.")
    _otp_store.pop(email, None)
    user = get_user_by_email(email)
    if not user:
        conn = __import__('database').get_conn()
        row = conn.execute(
            "SELECT id, username, email FROM users WHERE username = ?", (email,)
        ).fetchone()
        conn.close()
        if row:
            user = {"id": row["id"], "username": row["username"], "email": row["email"]}
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this email.")
    token = issue_token(user)
    return {"token": token, "user": user}


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
    return {k: float(v) for k, v in (breakdown or {}).items()}

def _auto_folder_name(score: float, session_label: str) -> str:
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
    folders = get_folders(user_id)
    for f in folders:
        if f["name"] == name:
            return f["id"]
    folder = create_folder(user_id, name)
    return folder["id"]

@app.post("/upload-images")
async def upload_images(
    files: List[UploadFile] = File(...),
    folder_id: Optional[int] = None,
    precious_indexes: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    precious_set: set[int] = set()
    if precious_indexes:
        for part in precious_indexes.split(','):
            part = part.strip()
            if part.isdigit():
                precious_set.add(int(part))

    from datetime import datetime as _dt
    existing = get_folders(user["id"])
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
    session_folder_cache: dict[str, int] = {}

    for idx, file in enumerate(files):
        contents = await file.read()
        is_precious = idx in precious_set

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
        b64 = base64.b64encode(contents).decode()
        caption = await loop.run_in_executor(executor, _generate_caption, b64)
        score_val = round(float(score), 2)

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
    ok = move_photo(photo_id, user["id"], folder_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Photo not found")
    return {"ok": True}


# ═══════════════════════════════════════════════════════════════════════
#  4. ENHANCE + ANALYZE
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