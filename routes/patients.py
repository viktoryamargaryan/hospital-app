# routes/patients.py — Full patient CRUD + search
# ─────────────────────────────────────────────────────────────
# FIXES:
#   1. PATIENT table uses manual PKs (not IDENTITY), so INSERT must supply PatientID.
#      We calculate MAX(PatientID)+1 safely.
#   2. Original schema has no CreatedBy column; removed from INSERT.
#   3. Added full UPDATE (edit) endpoint.
#   4. Added endpoints for per-patient sub-resources:
#      Medical History, Insurance, Emergency Contacts.
# ─────────────────────────────────────────────────────────────
from flask import Blueprint, request, jsonify, session
from database import query, execute
from functools import wraps

patients_bp = Blueprint("patients", __name__)


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return jsonify({"error": "Login required"}), 401
        return f(*args, **kwargs)
    return decorated


# ══════════════════════════════════════════════════════════════
#  PATIENTS — core CRUD
# ══════════════════════════════════════════════════════════════

@patients_bp.route("/api/patients")
@login_required
def get_patients():
    search = request.args.get("search", "").strip()
    page   = int(request.args.get("page",  1))
    limit  = int(request.args.get("limit", 20))
    offset = (page - 1) * limit

    if search:
        like = f"%{search}%"
        rows = query(
            """SELECT PatientID, FirstName, LastName, Phone, Address, DOB
               FROM PATIENT
               WHERE FirstName LIKE ? OR LastName LIKE ?
                  OR Phone     LIKE ? OR CAST(PatientID AS VARCHAR) = ?
               ORDER BY PatientID
               OFFSET ? ROWS FETCH NEXT ? ROWS ONLY""",
            (like, like, like, search, offset, limit)
        )
        total = query(
            """SELECT COUNT(*) AS cnt FROM PATIENT
               WHERE FirstName LIKE ? OR LastName LIKE ?
                  OR Phone LIKE ? OR CAST(PatientID AS VARCHAR) = ?""",
            (like, like, like, search), one=True
        )["cnt"]
    else:
        rows = query(
            """SELECT PatientID, FirstName, LastName, Phone, Address, DOB
               FROM PATIENT ORDER BY PatientID
               OFFSET ? ROWS FETCH NEXT ? ROWS ONLY""",
            (offset, limit)
        )
        total = query("SELECT COUNT(*) AS cnt FROM PATIENT", one=True)["cnt"]

    for p in rows:
        if p.get("DOB"):
            p["DOB"] = str(p["DOB"])[:10]

    return jsonify({"patients": rows, "total": total, "page": page, "limit": limit})


@patients_bp.route("/api/patients/<int:pid>")
@login_required
def get_patient(pid):
    patient = query("SELECT * FROM PATIENT WHERE PatientID = ?", (pid,), one=True)
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    if patient.get("DOB"):
        patient["DOB"] = str(patient["DOB"])[:10]
    return jsonify(patient)


@patients_bp.route("/api/patients", methods=["POST"])
@login_required
def create_patient():
    data = request.get_json()
    if not data.get("FirstName", "").strip() or not data.get("LastName", "").strip():
        return jsonify({"error": "First and Last name are required"}), 400

    # FIX: PATIENT uses manual PK — calculate next ID
    next_id = query("SELECT ISNULL(MAX(PatientID), 0) + 1 AS nid FROM PATIENT", one=True)["nid"]

    execute(
        """INSERT INTO PATIENT (PatientID, FirstName, LastName, DOB, Phone, Address)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (
            next_id,
            data["FirstName"].strip().capitalize(),
            data["LastName"].strip().capitalize(),
            data.get("DOB") or None,
            data.get("Phone", "").strip(),
            data.get("Address", "").strip(),
        )
    )
    return jsonify({"message": "Patient registered successfully", "id": next_id}), 201


@patients_bp.route("/api/patients/<int:pid>", methods=["PUT"])
@login_required
def update_patient(pid):
    data = request.get_json()
    if not data.get("FirstName", "").strip() or not data.get("LastName", "").strip():
        return jsonify({"error": "First and Last name are required"}), 400

    existing = query("SELECT 1 FROM PATIENT WHERE PatientID = ?", (pid,), one=True)
    if not existing:
        return jsonify({"error": "Patient not found"}), 404

    execute(
        """UPDATE PATIENT
           SET FirstName=?, LastName=?, DOB=?, Phone=?, Address=?
           WHERE PatientID=?""",
        (
            data["FirstName"].strip().capitalize(),
            data["LastName"].strip().capitalize(),
            data.get("DOB") or None,
            data.get("Phone", "").strip(),
            data.get("Address", "").strip(),
            pid,
        )
    )
    return jsonify({"message": "Patient updated successfully"})


@patients_bp.route("/api/patients/<int:pid>", methods=["DELETE"])
@login_required
def delete_patient(pid):
    if session.get("role") != "admin":
        return jsonify({"error": "Admin access required"}), 403

    existing = query("SELECT 1 FROM PATIENT WHERE PatientID = ?", (pid,), one=True)
    if not existing:
        return jsonify({"error": "Patient not found"}), 404

    # Delete child records first to respect FK constraints
    execute("DELETE FROM PRESCRIPTION_CONTAINS WHERE PrescriptionID IN (SELECT PrescriptionID FROM PRESCRIPTION WHERE AppointID IN (SELECT AppointID FROM APPOINTMENT WHERE PatientID=?))", (pid,))
    execute("DELETE FROM PRESCRIPTION WHERE AppointID IN (SELECT AppointID FROM APPOINTMENT WHERE PatientID=?)", (pid,))
    execute("DELETE FROM BILLING WHERE PatientID=?", (pid,))
    execute("DELETE FROM APPOINTMENT WHERE PatientID=?", (pid,))
    execute("DELETE FROM MEDICAL_HISTORY WHERE PatientID=?", (pid,))
    execute("DELETE FROM INSURANCE WHERE PatientID=?", (pid,))
    execute("DELETE FROM EMERGENCY_CONTACT WHERE PatientID=?", (pid,))
    execute("DELETE FROM PATIENT WHERE PatientID=?", (pid,))
    return jsonify({"message": "Patient deleted"})


# ══════════════════════════════════════════════════════════════
#  MEDICAL HISTORY  (per patient)
# ══════════════════════════════════════════════════════════════

@patients_bp.route("/api/patients/<int:pid>/medical-history")
@login_required
def get_medical_history(pid):
    rows = query("SELECT * FROM MEDICAL_HISTORY WHERE PatientID = ? ORDER BY HistoryID", (pid,))
    return jsonify(rows)


@patients_bp.route("/api/patients/<int:pid>/medical-history", methods=["POST"])
@login_required
def add_medical_history(pid):
    data    = request.get_json()
    next_id = query("SELECT ISNULL(MAX(HistoryID), 0) + 1 AS nid FROM MEDICAL_HISTORY", one=True)["nid"]
    execute(
        """INSERT INTO MEDICAL_HISTORY (HistoryID, PatientID, Diagnosis, SurgeryHistory, Allergies)
           VALUES (?, ?, ?, ?, ?)""",
        (next_id, pid,
         data.get("Diagnosis", ""),
         data.get("SurgeryHistory", ""),
         data.get("Allergies", ""))
    )
    return jsonify({"message": "Medical history added", "id": next_id}), 201


@patients_bp.route("/api/medical-history/<int:hid>", methods=["PUT"])
@login_required
def update_medical_history(hid):
    data = request.get_json()
    execute(
        """UPDATE MEDICAL_HISTORY
           SET Diagnosis=?, SurgeryHistory=?, Allergies=?
           WHERE HistoryID=?""",
        (data.get("Diagnosis", ""), data.get("SurgeryHistory", ""),
         data.get("Allergies", ""), hid)
    )
    return jsonify({"message": "Medical history updated"})


@patients_bp.route("/api/medical-history/<int:hid>", methods=["DELETE"])
@login_required
def delete_medical_history(hid):
    execute("DELETE FROM MEDICAL_HISTORY WHERE HistoryID=?", (hid,))
    return jsonify({"message": "Record deleted"})


# ══════════════════════════════════════════════════════════════
#  INSURANCE  (per patient)
# ══════════════════════════════════════════════════════════════

@patients_bp.route("/api/patients/<int:pid>/insurance")
@login_required
def get_insurance(pid):
    rows = query("SELECT * FROM INSURANCE WHERE PatientID = ? ORDER BY InsuranceID", (pid,))
    return jsonify(rows)


@patients_bp.route("/api/patients/<int:pid>/insurance", methods=["POST"])
@login_required
def add_insurance(pid):
    data    = request.get_json()
    if not data.get("ProviderName", "").strip():
        return jsonify({"error": "Provider name is required"}), 400
    next_id = query("SELECT ISNULL(MAX(InsuranceID), 0) + 1 AS nid FROM INSURANCE", one=True)["nid"]
    execute(
        """INSERT INTO INSURANCE (InsuranceID, PatientID, ProviderName, PolicyNumber, CoverageDetails)
           VALUES (?, ?, ?, ?, ?)""",
        (next_id, pid,
         data.get("ProviderName", "").strip(),
         data.get("PolicyNumber", "").strip(),
         data.get("CoverageDetails", ""))
    )
    return jsonify({"message": "Insurance record added", "id": next_id}), 201


@patients_bp.route("/api/insurance/<int:iid>", methods=["DELETE"])
@login_required
def delete_insurance(iid):
    execute("DELETE FROM INSURANCE WHERE InsuranceID=?", (iid,))
    return jsonify({"message": "Insurance record deleted"})


# ══════════════════════════════════════════════════════════════
#  EMERGENCY CONTACTS  (per patient)
# ══════════════════════════════════════════════════════════════

@patients_bp.route("/api/patients/<int:pid>/emergency-contacts")
@login_required
def get_emergency_contacts(pid):
    rows = query(
        "SELECT * FROM EMERGENCY_CONTACT WHERE PatientID = ? ORDER BY ContactID", (pid,)
    )
    return jsonify(rows)


@patients_bp.route("/api/patients/<int:pid>/emergency-contacts", methods=["POST"])
@login_required
def add_emergency_contact(pid):
    data    = request.get_json()
    if not data.get("ContactName", "").strip():
        return jsonify({"error": "Contact name is required"}), 400
    next_id = query("SELECT ISNULL(MAX(ContactID), 0) + 1 AS nid FROM EMERGENCY_CONTACT", one=True)["nid"]
    execute(
        """INSERT INTO EMERGENCY_CONTACT (ContactID, PatientID, ContactName, Relationship, Phone)
           VALUES (?, ?, ?, ?, ?)""",
        (next_id, pid,
         data.get("ContactName", "").strip(),
         data.get("Relationship", "").strip(),
         data.get("Phone", "").strip())
    )
    return jsonify({"message": "Emergency contact added", "id": next_id}), 201


@patients_bp.route("/api/emergency-contacts/<int:cid>", methods=["DELETE"])
@login_required
def delete_emergency_contact(cid):
    execute("DELETE FROM EMERGENCY_CONTACT WHERE ContactID=?", (cid,))
    return jsonify({"message": "Contact deleted"})
