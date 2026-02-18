import cv2
import numpy as np
import hashlib

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
)

def read_image_bytes(image_bytes):
    np_arr = np.frombuffer(image_bytes, np.uint8)
    return cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

def blur_score(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    return min(variance / 15, 30)

def brightness_score(img):
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    brightness = hsv[:, :, 2].mean()
    return max(0, 20 - abs(brightness - 140) / 7)

def contrast_score(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return min(gray.std() / 3, 20)

def face_bonus(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 5)
    return min(len(faces) * 10, 20)

def image_hash(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, (8, 8))
    avg = gray.mean()
    bits = ''.join('1' if p > avg else '0' for p in gray.flatten())
    return hashlib.sha256(bits.encode()).hexdigest()

def calculate_score(img, duplicate_hashes):
    blur = blur_score(img)
    brightness = brightness_score(img)
    contrast = contrast_score(img)
    face = face_bonus(img)

    img_hash = image_hash(img)
    duplicate_penalty = 25 if img_hash in duplicate_hashes else 0

    score = blur + brightness + contrast + face - duplicate_penalty
    score = max(0, min(score, 100))

    return score, img_hash

def enhance_image(img):
    img = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)

    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
    cl = clahe.apply(l)
    limg = cv2.merge((cl, a, b))
    img = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)

    kernel = np.array([[0,-1,0],
                       [-1,5,-1],
                       [0,-1,0]])
    img = cv2.filter2D(img, -1, kernel)

    return img
