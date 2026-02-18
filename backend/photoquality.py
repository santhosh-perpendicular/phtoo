import cv2
import numpy as np
import hashlib

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
)

def read_image(image_path):
    return cv2.imdecode(
        np.fromfile(image_path, dtype=np.uint8),
        cv2.IMREAD_COLOR
    )

def blur_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    return min(variance / 15, 30)   # more spread

def brightness_score(img):
    if img is None:
        return 0
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    brightness = hsv[:, :, 2].mean()
    return max(0, 20 - abs(brightness - 140) / 7)

def contrast_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return min(gray.std() / 3, 20)

def face_bonus(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 5)
    return min(len(faces) * 10, 20)   # scale instead of flat bonus

def image_hash(img):
    if img is None:
        return ""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (8, 8))
    avg = gray.mean()
    bits = ''.join('1' if p > avg else '0' for p in gray.flatten())
    return hashlib.sha256(bits.encode()).hexdigest()

def final_score(image_path, duplicate_hashes):
    img = read_image(image_path)

    blur = blur_score(img)
    brightness = brightness_score(img)
    contrast = contrast_score(img)
    face = face_bonus(img)

    img_hash = image_hash(img)
    duplicate_penalty = 25 if img_hash in duplicate_hashes else 0

    score = blur + brightness + contrast + face - duplicate_penalty
    score = max(0, min(score, 100))

    return score, img_hash
