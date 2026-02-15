import cv2
import numpy as np
import hashlib

face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

def read_image(image_path):
    img = cv2.imdecode(np.fromfile(image_path, dtype=np.uint8), cv2.IMREAD_COLOR)
    return img

def blur_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return min(cv2.Laplacian(gray, cv2.CV_64F).var() / 5, 40)

def brightness_score(img):
    if img is None:
        return 0
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    return min(max(hsv[:, :, 2].mean() / 2.55, 0), 20)

def contrast_score(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return min(gray.std() / 2, 20)

def face_bonus(img):
    if img is None:
        return 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
    return 20 if len(faces) > 0 else 0

def image_hash(img):
    if img is None:
        return ""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (8, 8))
    avg = gray.mean()
    hash_str = ''.join(['1' if px > avg else '0' for px in gray.flatten()])
    return hashlib.sha256(hash_str.encode()).hexdigest()

def final_score(image_path, duplicate_hashes=set()):
    img = read_image(image_path)
    blur = blur_score(img)
    bright = brightness_score(img)
    contrast = contrast_score(img)
    face = face_bonus(img)
    img_hash = image_hash(img)
    duplicate_penalty = 20 if img_hash in duplicate_hashes else 0
    score = blur + bright + contrast + face - duplicate_penalty
    score = max(0, min(score, 100))
    return score, img_hash
