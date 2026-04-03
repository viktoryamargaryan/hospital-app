# routes/auth.py — Login, logout, register, change-password
# ─────────────────────────────────────────────────────────────
# FIXES:
#   1. Login was broken: it checked `if not password` (always True for non-empty)
#      instead of actually verifying against the stored hash.
#   2. Seed data stores passwords as plain-text ('admin123'), so we support
#      BOTH plain-text (legacy) AND werkzeug-hashed passwords transparently.
#      After a user changes their password it will always be hashed going forward.
# ─────────────────────────────────────────────────────────────
from flask import Blueprint, request, jsonify, session
from werkzeug.security import check_password_hash, generate_password_hash
from database import query, execute

auth_bp = Blueprint("auth", __name__)


def _verify_password(stored: str, provided: str) -> bool:
    """
    Dual-mode password check.
    Werkzeug hashes start with 'pbkdf2:' or 'scrypt:'.
    Anything else is treated as the legacy plain-text seed password.
    """
    if stored.startswith("pbkdf2:") or stored.startswith("scrypt:"):
        return check_password_hash(stored, provided)
    return stored == provided   # legacy plain-text fallback


# ── LOGIN ────────────────────────────────────────────────────
@auth_bp.route("/api/auth/login", methods=["POST"])
def login():
    data     = request.get_json()
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"error": "Username and password required"}), 400

    user = query(
        "SELECT UserID, Username, Password, FullName, Role FROM USERS WHERE Username = ?",
        (username,), one=True
    )
    if not user:
        return jsonify({"error": "Invalid username or password"}), 401

    # FIX: actually verify the password (was `if not password` before)
    if not _verify_password(user["Password"], password):
        return jsonify({"error": "Invalid username or password"}), 401

    session["user_id"]   = user["UserID"]
    session["username"]  = user["Username"]
    session["full_name"] = user["FullName"]
    session["role"]      = user["Role"]

    return jsonify({
        "message": "Login successful",
        "user": {
            "id":       user["UserID"],
            "username": user["Username"],
            "fullName": user["FullName"],
            "role":     user["Role"],
        }
    })


# ── LOGOUT ───────────────────────────────────────────────────
@auth_bp.route("/api/auth/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"message": "Logged out"})


# ── CURRENT USER ─────────────────────────────────────────────
@auth_bp.route("/api/auth/me")
def me():
    if "user_id" not in session:
        return jsonify({"error": "Not logged in"}), 401
    return jsonify({
        "id":       session["user_id"],
        "username": session["username"],
        "fullName": session["full_name"],
        "role":     session["role"],
    })


# ── REGISTER (admin only) ────────────────────────────────────
@auth_bp.route("/api/auth/register", methods=["POST"])
def register():
    if session.get("role") != "admin":
        return jsonify({"error": "Admin access required"}), 403

    data     = request.get_json()
    username = data.get("username", "").strip()
    password = data.get("password", "")
    fullname = data.get("fullName", "").strip()
    role     = data.get("role", "assistant")

    if not username or not password or not fullname:
        return jsonify({"error": "All fields are required"}), 400
    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400
    if role not in ("admin", "assistant"):
        return jsonify({"error": "Role must be admin or assistant"}), 400

    existing = query("SELECT 1 FROM USERS WHERE Username = ?", (username,), one=True)
    if existing:
        return jsonify({"error": "Username already exists"}), 409

    hashed = generate_password_hash(password)
    execute(
        "INSERT INTO USERS (Username, Password, FullName, Role) VALUES (?, ?, ?, ?)",
        (username, hashed, fullname, role)
    )
    return jsonify({"message": f"User '{username}' created successfully"}), 201


# ── CHANGE PASSWORD ──────────────────────────────────────────
@auth_bp.route("/api/auth/change-password", methods=["PUT"])
def change_password():
    if "user_id" not in session:
        return jsonify({"error": "Not logged in"}), 401

    data         = request.get_json()
    old_password = data.get("oldPassword", "")
    new_password = data.get("newPassword", "")

    if not old_password or not new_password:
        return jsonify({"error": "Both old and new passwords are required"}), 400
    if len(new_password) < 6:
        return jsonify({"error": "New password must be at least 6 characters"}), 400

    user = query("SELECT Password FROM USERS WHERE UserID = ?",
                 (session["user_id"],), one=True)
    if not user:
        return jsonify({"error": "User not found"}), 404

    if not _verify_password(user["Password"], old_password):
        return jsonify({"error": "Current password is incorrect"}), 401

    hashed = generate_password_hash(new_password)
    execute("UPDATE USERS SET Password = ? WHERE UserID = ?",
            (hashed, session["user_id"]))
    return jsonify({"message": "Password changed successfully"})
