# database.py — Central database connection
# Supports both local SQL Server and Azure SQL Database

import pyodbc
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# ============================================================
# DATABASE CONFIGURATION - Uses environment variables
# ============================================================
# For local development, these will use defaults
# For production, set these in your hosting platform's env vars

SERVER = os.getenv(
    "DATABASE_SERVER",
    r".\SQLEXPRESS"  # Default: Local SQL Server
)

DATABASE = os.getenv(
    "DATABASE_NAME",
    "HospitalDB"
)

DB_USER = os.getenv("DATABASE_USER", "")
DB_PASSWORD = os.getenv("DATABASE_PASSWORD", "")

# ============================================================

def get_connection():
    """
    Return a live pyodbc connection.
    Automatically detects local vs cloud database.
    Call this in every route.
    """
    
    if DB_USER and DB_PASSWORD:
        # Azure SQL Server connection (for cloud/production)
        # Uses username and password authentication
        conn_str = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
            f"Connection Timeout=30;"
        )
    else:
        # Local SQL Server connection (for development)
        # Uses Windows Authentication (Trusted Connection)
        conn_str = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            f"Trusted_Connection=yes;"
        )
    
    try:
        return pyodbc.connect(conn_str)
    except Exception as e:
        print(f"Database connection error: {str(e)}")
        raise


def query(sql, params=(), one=False):
    """
    Run a SELECT query.
    Returns a list of dicts, or a single dict if one=True.
    
    Example:
        users = query("SELECT * FROM Users WHERE Age > ?", (18,))
        user = query("SELECT * FROM Users WHERE ID = ?", (1,), one=True)
    """
    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(sql, params)
        
        cols = [col[0] for col in cursor.description]
        
        if one:
            row = cursor.fetchone()
            return dict(zip(cols, row)) if row else None
        
        rows = cursor.fetchall()
        return [dict(zip(cols, row)) for row in rows]
    
    except Exception as e:
        print(f"Query error: {str(e)}")
        raise
    
    finally:
        if conn:
            conn.close()


def execute(sql, params=()):
    """
    Run INSERT / UPDATE / DELETE and commit.
    Returns the last inserted row ID (if available).
    
    Example:
        new_id = execute(
            "INSERT INTO Patients (Name, Age) VALUES (?, ?)",
            ("John Doe", 45)
        )
    """
    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(sql, params)
        
        # Try to get the new row's ID (for INSERT statements)
        last_id = None
        try:
            cursor.execute("SELECT @@IDENTITY")
            last_id = cursor.fetchone()[0]
        except Exception:
            pass
        
        conn.commit()
        return last_id
    
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Execute error: {str(e)}")
        raise
    
    finally:
        if conn:
            conn.close()
