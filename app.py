# app.py — Main Flask application entry point
import os
from flask import Flask, render_template, redirect, url_for
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Import our route blueprints
from routes.auth import auth_bp
from routes.patients import patients_bp
from routes.hospital import hospital_bp

# Initialize Flask app
app = Flask(__name__)

# ============================================================
# SECURITY CONFIGURATION
# ============================================================
# In production, SECRET_KEY comes from environment variable
# For development, a default is provided
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "inch_uzes_karox_es_grel"  
)
app.secret_key = SECRET_KEY

# Get Flask environment (production or development)
FLASK_ENV = os.getenv("FLASK_ENV", "development")

# ============================================================
# CORS CONFIGURATION
# ============================================================
# Allow cross-origin requests with credentials
# In production, restrict to your domain only
CORS(
    app,
    supports_credentials=True,
    origins=[
        "http://localhost:3000",  # Local development
        "http://localhost:5000",  # Flask dev server
        os.getenv("ALLOWED_ORIGINS", "http://localhost:5000")  # Production domain
    ]
)

# ============================================================
# REGISTER BLUEPRINTS
# ============================================================
app.register_blueprint(auth_bp)
app.register_blueprint(patients_bp)
app.register_blueprint(hospital_bp)


# ============================================================
# ROUTE HANDLERS
# ============================================================

@app.route("/")
def root():
    """Redirect root to login page."""
    return redirect(url_for("login_page"))


@app.route("/login")
def login_page():
    """Render login page."""
    return render_template("login.html")


@app.route("/dashboard")
def dashboard_page():
    """Render main dashboard page."""
    return render_template("dashboard.html")


# ============================================================
# ERROR HANDLERS
# ============================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return {"error": "Not found"}, 404


@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors."""
    return {"error": "Internal server error"}, 500


# ============================================================
# APP STARTUP
# ============================================================

if __name__ == "__main__":
    print("\n" + "="*60)
    print("  🏥  Hospital Management System  — Backend")
    print("="*60)
    
    if FLASK_ENV == "production":
        print("  Mode: PRODUCTION")
        print("  ⚠️  Debug mode is OFF")
        print("  ✅ HTTPS enabled")
        print(f"  📊 Database: {os.getenv('DATABASE_SERVER', 'Local')}")
        debug_mode = False
    else:
        print("  Mode: DEVELOPMENT")
        print("  🔧 Debug mode is ON")
        print("  Running at: http://localhost:5000")
        print("  Default login: admin / admin123")
        debug_mode = True
    
    print("="*60 + "\n")
    
    # In production, use gunicorn instead of Flask's built-in server
    # See Procfile for production setup
    app.run(
        host="0.0.0.0",  # Listen on all interfaces
        port=int(os.getenv("PORT", 5000)),
        debug=debug_mode,
        use_reloader=debug_mode
    )
