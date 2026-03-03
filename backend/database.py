"""
database.py — SQLite persistence for HACKX
Tables: users, folders, photos
"""

import sqlite3
import hashlib
import os
from datetime import datetime

DB_PATH = os.getenv("DB_PATH", "hackx.db")


def get_conn():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_conn()
    c = conn.cursor()

    # ── users ──────────────────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            username    TEXT    UNIQUE NOT NULL,
            password    TEXT    NOT NULL,
            created_at  TEXT    DEFAULT (datetime('now'))
        )
    """)

    # ── folders ────────────────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS folders (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL,
            name        TEXT    NOT NULL,
            created_at  TEXT    DEFAULT (datetime('now')),
            FOREIGN KEY (user_id) REFERENCES users(id),
            UNIQUE(user_id, name)
        )
    """)

    # ── photos ─────────────────────────────────────────────────────────
    c.execute("""
        CREATE TABLE IF NOT EXISTS photos (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL,
            folder_id   INTEGER,
            filename    TEXT    NOT NULL,
            filepath    TEXT,
            score       REAL    DEFAULT 0,
            caption     TEXT,
            is_precious INTEGER DEFAULT 0,
            breakdown   TEXT,
            created_at  TEXT    DEFAULT (datetime('now')),
            FOREIGN KEY (user_id)   REFERENCES users(id),
            FOREIGN KEY (folder_id) REFERENCES folders(id)
        )
    """)

    # ── MIGRATION: add filepath column if it doesn't exist yet ─────────
    existing_cols = [row[1] for row in c.execute("PRAGMA table_info(photos)").fetchall()]
    if 'filepath' not in existing_cols:
        c.execute("ALTER TABLE photos ADD COLUMN filepath TEXT DEFAULT ''")

    # Seed default admin user (password: admin)
    _seed_user(c, "admin", "admin")

    conn.commit()
    conn.close()


# ── helpers ───────────────────────────────────────────────────────────

def _hash(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def _seed_user(cursor, username: str, password: str):
    try:
        cursor.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            (username, _hash(password))
        )
    except sqlite3.IntegrityError:
        pass  # already exists


# ── AUTH ──────────────────────────────────────────────────────────────

def authenticate(username: str, password: str) -> dict | None:
    conn = get_conn()
    row = conn.execute(
        "SELECT * FROM users WHERE username = ? AND password = ?",
        (username, _hash(password))
    ).fetchone()
    conn.close()
    if row:
        return {"id": row["id"], "username": row["username"]}
    return None


def create_user(username: str, password: str) -> dict | None:
    conn = get_conn()
    try:
        conn.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            (username, _hash(password))
        )
        conn.commit()
        row = conn.execute(
            "SELECT id, username FROM users WHERE username = ?", (username,)
        ).fetchone()
        conn.close()
        return {"id": row["id"], "username": row["username"]}
    except sqlite3.IntegrityError:
        conn.close()
        return None


# ── FOLDERS ───────────────────────────────────────────────────────────

def get_folders(user_id: int) -> list[dict]:
    conn = get_conn()
    rows = conn.execute(
        "SELECT * FROM folders WHERE user_id = ? ORDER BY name", (user_id,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def create_folder(user_id: int, name: str) -> dict | None:
    conn = get_conn()
    try:
        conn.execute(
            "INSERT INTO folders (user_id, name) VALUES (?, ?)", (user_id, name)
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM folders WHERE user_id = ? AND name = ?", (user_id, name)
        ).fetchone()
        conn.close()
        return dict(row)
    except sqlite3.IntegrityError:
        conn.close()
        return None


def delete_folder(folder_id: int, user_id: int) -> bool:
    conn = get_conn()
    conn.execute(
        "DELETE FROM photos WHERE folder_id = ? AND user_id = ?", (folder_id, user_id)
    )
    cur = conn.execute(
        "DELETE FROM folders WHERE id = ? AND user_id = ?", (folder_id, user_id)
    )
    conn.commit()
    conn.close()
    return cur.rowcount > 0


# ── PHOTOS ────────────────────────────────────────────────────────────

def save_photo(user_id: int, folder_id: int | None, filename: str,
               score: float, caption: str, is_precious: bool,
               breakdown: str, filepath: str = "") -> int:
    conn = get_conn()
    cur = conn.execute(
        """INSERT INTO photos
           (user_id, folder_id, filename, filepath, score, caption, is_precious, breakdown)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (user_id, folder_id, filename, filepath, score,
         caption, 1 if is_precious else 0, breakdown)
    )
    conn.commit()
    photo_id = cur.lastrowid
    conn.close()
    return photo_id


def get_photos(user_id: int, folder_id: int | None = None) -> list[dict]:
    conn = get_conn()
    if folder_id is not None:
        rows = conn.execute(
            "SELECT * FROM photos WHERE user_id = ? AND folder_id = ? ORDER BY score DESC",
            (user_id, folder_id)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM photos WHERE user_id = ? ORDER BY score DESC", (user_id,)
        ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def delete_photo(photo_id: int, user_id: int) -> bool:
    conn = get_conn()
    # Never delete precious photos automatically — caller must force
    cur = conn.execute(
        "DELETE FROM photos WHERE id = ? AND user_id = ?", (photo_id, user_id)
    )
    conn.commit()
    conn.close()
    return cur.rowcount > 0


def get_photo(photo_id: int, user_id: int) -> dict | None:
    conn = get_conn()
    row = conn.execute(
        "SELECT * FROM photos WHERE id = ? AND user_id = ?", (photo_id, user_id)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def set_precious(photo_id: int, user_id: int, precious: bool) -> bool:
    conn = get_conn()
    cur = conn.execute(
        "UPDATE photos SET is_precious = ? WHERE id = ? AND user_id = ?",
        (1 if precious else 0, photo_id, user_id)
    )
    conn.commit()
    conn.close()
    return cur.rowcount > 0


def move_photo(photo_id: int, user_id: int, folder_id: int | None) -> bool:
    conn = get_conn()
    cur = conn.execute(
        "UPDATE photos SET folder_id = ? WHERE id = ? AND user_id = ?",
        (folder_id, photo_id, user_id)
    )
    conn.commit()
    conn.close()
    return cur.rowcount > 0
