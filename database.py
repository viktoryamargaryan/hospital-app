# database.py — Central database connection
# Supports both local SQL Server and Azure SQL Database

import pymssql
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
    try:
        if DB_USER and DB_PASSWORD:
            conn = pymssql.connect(
                server=SERVER,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DATABASE,
                timeout=30
            )
        else:
            conn = pymssql.connect(
                server=SERVER,
                database=DATABASE,
                timeout=30
            )
        return conn
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
        cursor = conn.cursor(as_dict=True)
        cursor.execute(sql, params)
        if one:
            return cursor.fetchone()
        rows = cursor.fetchall()
        return rows if rows else []
    
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
