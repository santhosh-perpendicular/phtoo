import cv2
import numpy as np
import hashlib

# Load Haar cascade for face detection
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

# Safely read image (handles spaces, Unicode paths)
def read_image(image_path):
    img = cv2.imdecode(np.fromfile(image_path, dtype=np.uint8), cv2.IMREAD_COLOR)
    return img

# 1️⃣ Blur / Sharpness
def blur_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    score = min(variance / 5, 40)  # max 40
    return score

# 2️⃣ Brightness
def brightness_score(img):
    if img is None:
        return 0
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    brightness = hsv[:, :, 2].mean()
    score = min(max(brightness / 2.55, 0), 20)  # max 20
    return score

# 3️⃣ Contrast / Detail
def contrast_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    score = min(gray.std() / 2, 20)  # max 20
    return score

# 4️⃣ Face bonus
def face_bonus(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
    return 20 if len(faces) > 0 else 0

# 5️⃣ Duplicate detection
def image_hash(img):
    if img is None:
        return ""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (8, 8))
    avg = gray.mean()
    hash_str = ''.join(['1' if px > avg else '0' for px in gray.flatten()])
    return hashlib.sha256(hash_str.encode()).hexdigest()

# 6️⃣ Final score calculation
def final_score(image_path, duplicate_hashes=set()):
    img = read_image(image_path)
    blur = blur_score(img)
    bright = brightness_score(img)
    contrast = contrast_score(img)
    face = face_bonus(img)
    img_hash = image_hash(img)
    duplicate_penalty = 50 if img_hash in duplicate_hashes else 0
    duplicate_hashes.add(img_hash)
    score = blur + bright + contrast + face - duplicate_penalty
    score = max(0, min(score, 100))
    return score, img_hash
