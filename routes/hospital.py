# routes/hospital.py — Doctors, Appointments, Billing, Rooms, Departments, Staff,
#                      Prescriptions, Reports/Views, Stats, Users
# ─────────────────────────────────────────────────────────────
# FIXES & ADDITIONS:
#   1. APPOINTMENT uses manual PK — INSERT now calculates MAX+1.
#   2. Added DELETE appointment endpoint.
#   3. Added full edit (PUT) for appointment (date/time/doctor/patient).
#   4. Added Staff endpoints (was in DB but not wired to API).
#   5. Added Prescription endpoints (per appointment).
#   6. Added Reports endpoints that use the DB Views defined in 4.Views.sql.
#   7. Added Doctor Workload report (uses DoctorWorkload view).
#   8. Added Department revenue report (calls stored procedure via raw SQL).
#   9. Added Room status update endpoint (calls usp_UpdateRoomStatus logic).
#  10. Stats endpoint enriched with nurse/staff count.
# ─────────────────────────────────────────────────────────────
from flask import Blueprint, request, jsonify, session
from database import query, execute
from functools import wraps

hospital_bp = Blueprint("hospital", __name__)


def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            return jsonify({"error": "Login required"}), 401
        return f(*args, **kwargs)
    return decorated


# ════════════════════════════════════════════════════════════
#  DASHBOARD STATS
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/stats")
@login_required
def get_stats():
    patients      = query("SELECT COUNT(*) AS n FROM PATIENT",      one=True)["n"]
    doctors       = query("SELECT COUNT(*) AS n FROM DOCTOR",       one=True)["n"]
    scheduled     = query("SELECT COUNT(*) AS n FROM APPOINTMENT WHERE Status='Scheduled'", one=True)["n"]
    pending_bills = query("SELECT COUNT(*) AS n FROM BILLING WHERE PaymentStatus='Pending'", one=True)["n"]
    departments   = query("SELECT COUNT(*) AS n FROM DEPARTMENT",   one=True)["n"]
    rooms_free    = query("SELECT COUNT(*) AS n FROM ROOM WHERE Status='Vacant'", one=True)["n"]
    staff_count   = query("SELECT COUNT(*) AS n FROM STAFF",        one=True)["n"]
    # Total revenue from paid bills
    revenue       = query("SELECT ISNULL(SUM(TotalAmount),0) AS n FROM BILLING WHERE PaymentStatus='Paid'", one=True)["n"]

    return jsonify({
        "patients":      patients,
        "doctors":       doctors,
        "appointments":  scheduled,
        "pending_bills": pending_bills,
        "departments":   departments,
        "rooms_free":    rooms_free,
        "staff":         staff_count,
        "revenue":       float(revenue),
    })


# ════════════════════════════════════════════════════════════
#  DOCTORS
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/doctors")
@login_required
def get_doctors():
    search = request.args.get("search", "").strip()
    dept   = request.args.get("dept", "").strip()

    conditions, params = [], []
    if search:
        like = f"%{search}%"
        conditions.append("(D.FullName LIKE ? OR D.Specialization LIKE ?)")
        params += [like, like]
    if dept:
        conditions.append("D.DeptID = ?")
        params.append(dept)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    rows = query(
        f"""SELECT D.DoctorID, D.FullName, D.Specialization, D.LicenseNumber,
                   DEP.DeptName AS Department, DEP.DeptID
            FROM DOCTOR D JOIN DEPARTMENT DEP ON D.DeptID = DEP.DeptID
            {where}
            ORDER BY D.FullName""",
        params
    )
    return jsonify(rows)


@hospital_bp.route("/api/doctors/<int:did>/schedule")
@login_required
def get_doctor_schedule(did):
    """Get all appointments for a specific doctor (uses usp_GetDoctorSchedule logic)."""
    date = request.args.get("date", "")
    if date:
        rows = query(
            """SELECT A.Time, P.FirstName + ' ' + P.LastName AS PatientName,
                      P.Phone, A.Status, A.AppointID
               FROM APPOINTMENT A JOIN PATIENT P ON A.PatientID = P.PatientID
               WHERE A.DoctorID = ? AND A.Date = ?
               ORDER BY A.Time""",
            (did, date)
        )
    else:
        rows = query(
            """SELECT A.Date, A.Time, P.FirstName + ' ' + P.LastName AS PatientName,
                      P.Phone, A.Status, A.AppointID
               FROM APPOINTMENT A JOIN PATIENT P ON A.PatientID = P.PatientID
               WHERE A.DoctorID = ?
               ORDER BY A.Date DESC, A.Time""",
            (did,)
        )
    for r in rows:
        if r.get("Date"): r["Date"] = str(r["Date"])[:10]
    return jsonify(rows)


# ════════════════════════════════════════════════════════════
#  APPOINTMENTS — full CRUD
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/appointments")
@login_required
def get_appointments():
    search = request.args.get("search", "").strip()
    status = request.args.get("status", "").strip()
    page   = int(request.args.get("page",  1))
    limit  = int(request.args.get("limit", 20))
    offset = (page - 1) * limit

    conditions, params = [], []
    if search:
        like = f"%{search}%"
        conditions.append("(P.FirstName LIKE ? OR P.LastName LIKE ? OR D.FullName LIKE ?)")
        params += [like, like, like]
    if status:
        conditions.append("A.Status = ?")
        params.append(status)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    rows = query(
        f"""SELECT A.AppointID, A.Date, A.Time, A.Status,
                   P.FirstName + ' ' + P.LastName AS PatientName,
                   D.FullName AS DoctorName,
                   P.PatientID, D.DoctorID
            FROM APPOINTMENT A
            JOIN PATIENT P ON A.PatientID = P.PatientID
            JOIN DOCTOR  D ON A.DoctorID  = D.DoctorID
            {where}
            ORDER BY A.Date DESC, A.Time
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY""",
        params + [offset, limit]
    )
    for a in rows:
        if a.get("Date"): a["Date"] = str(a["Date"])[:10]
        if a.get("Time"): a["Time"] = str(a["Time"])

    total = query(
        f"""SELECT COUNT(*) AS n FROM APPOINTMENT A
            JOIN PATIENT P ON A.PatientID = P.PatientID
            JOIN DOCTOR  D ON A.DoctorID  = D.DoctorID
            {where}""",
        params, one=True
    )["n"]

    return jsonify({"appointments": rows, "total": total})


@hospital_bp.route("/api/appointments", methods=["POST"])
@login_required
def create_appointment():
    data = request.get_json()
    if not data.get("PatientID") or not data.get("DoctorID") or not data.get("Date"):
        return jsonify({"error": "PatientID, DoctorID and Date are required"}), 400

    time_val = data.get("Time", "09:00") or "09:00"

    # FIX: APPOINTMENT uses manual PK
    next_id = query("SELECT ISNULL(MAX(AppointID), 0) + 1 AS nid FROM APPOINTMENT", one=True)["nid"]

    # Check doctor double-booking (mirrors usp_BookAppointment logic)
    conflict = query(
        "SELECT 1 FROM APPOINTMENT WHERE DoctorID=? AND Date=? AND Time=? AND Status='Scheduled'",
        (data["DoctorID"], data["Date"], time_val), one=True
    )
    if conflict:
        return jsonify({"error": "Doctor already has an appointment at this date/time"}), 409

    execute(
        """INSERT INTO APPOINTMENT (AppointID, Date, Time, Status, PatientID, DoctorID)
           VALUES (?, ?, ?, 'Scheduled', ?, ?)""",
        (next_id, data["Date"], time_val, data["PatientID"], data["DoctorID"])
    )
    return jsonify({"message": "Appointment booked", "id": next_id}), 201


@hospital_bp.route("/api/appointments/<int:apt_id>", methods=["PUT"])
@login_required
def update_appointment(apt_id):
    """Update status, date, time or doctor — all in one endpoint."""
    data = request.get_json()

    existing = query("SELECT * FROM APPOINTMENT WHERE AppointID=?", (apt_id,), one=True)
    if not existing:
        return jsonify({"error": "Appointment not found"}), 404

    # Allow partial updates: fall back to existing values
    new_status  = data.get("status",    existing["Status"])
    new_date    = data.get("Date",      str(existing["Date"])[:10])
    new_time    = data.get("Time",      str(existing["Time"]))
    new_patient = data.get("PatientID", existing["PatientID"])
    new_doctor  = data.get("DoctorID",  existing["DoctorID"])

    if new_status not in ("Scheduled", "Completed", "Cancelled"):
        return jsonify({"error": "Invalid status"}), 400

    execute(
        """UPDATE APPOINTMENT
           SET Status=?, Date=?, Time=?, PatientID=?, DoctorID=?
           WHERE AppointID=?""",
        (new_status, new_date, new_time, new_patient, new_doctor, apt_id)
    )
    return jsonify({"message": "Appointment updated"})


@hospital_bp.route("/api/appointments/<int:apt_id>", methods=["DELETE"])
@login_required
def delete_appointment(apt_id):
    if session.get("role") != "admin":
        return jsonify({"error": "Admin access required"}), 403

    existing = query("SELECT 1 FROM APPOINTMENT WHERE AppointID=?", (apt_id,), one=True)
    if not existing:
        return jsonify({"error": "Appointment not found"}), 404

    # Remove prescriptions linked to this appointment first
    execute("DELETE FROM PRESCRIPTION_CONTAINS WHERE PrescriptionID IN (SELECT PrescriptionID FROM PRESCRIPTION WHERE AppointID=?)", (apt_id,))
    execute("DELETE FROM PRESCRIPTION WHERE AppointID=?", (apt_id,))
    execute("DELETE FROM BILLING WHERE AppointID=?", (apt_id,))
    execute("DELETE FROM APPOINTMENT WHERE AppointID=?", (apt_id,))
    return jsonify({"message": "Appointment deleted"})


# ════════════════════════════════════════════════════════════
#  PRESCRIPTIONS  (per appointment)
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/appointments/<int:apt_id>/prescriptions")
@login_required
def get_prescriptions(apt_id):
    """Get prescriptions with medicine details for an appointment."""
    rows = query(
        """SELECT PR.PrescriptionID, PR.DateIssued,
                  M.MedicineID, M.Name AS MedicineName, M.Unit,
                  PC.Dosage
           FROM PRESCRIPTION PR
           JOIN PRESCRIPTION_CONTAINS PC ON PR.PrescriptionID = PC.PrescriptionID
           JOIN MEDICINE M ON PC.MedicineID = M.MedicineID
           WHERE PR.AppointID = ?
           ORDER BY PR.PrescriptionID""",
        (apt_id,)
    )
    for r in rows:
        if r.get("DateIssued"): r["DateIssued"] = str(r["DateIssued"])[:10]
    return jsonify(rows)


@hospital_bp.route("/api/appointments/<int:apt_id>/prescriptions", methods=["POST"])
@login_required
def add_prescription(apt_id):
    """Issue a prescription (mirrors usp_IssuePrescription logic)."""
    data = request.get_json()
    if not data.get("MedicineID") or not data.get("Dosage"):
        return jsonify({"error": "MedicineID and Dosage are required"}), 400

    # Create a new PRESCRIPTION row, then link the medicine
    next_pres_id = query("SELECT ISNULL(MAX(PrescriptionID), 0) + 1 AS nid FROM PRESCRIPTION", one=True)["nid"]

    execute(
        "INSERT INTO PRESCRIPTION (PrescriptionID, DateIssued, AppointID) VALUES (?, CAST(GETDATE() AS DATE), ?)",
        (next_pres_id, apt_id)
    )
    execute(
        "INSERT INTO PRESCRIPTION_CONTAINS (PrescriptionID, MedicineID, Dosage) VALUES (?, ?, ?)",
        (next_pres_id, data["MedicineID"], data["Dosage"])
    )
    return jsonify({"message": "Prescription issued", "id": next_pres_id}), 201


@hospital_bp.route("/api/prescriptions/<int:pres_id>", methods=["DELETE"])
@login_required
def delete_prescription(pres_id):
    execute("DELETE FROM PRESCRIPTION_CONTAINS WHERE PrescriptionID=?", (pres_id,))
    execute("DELETE FROM PRESCRIPTION WHERE PrescriptionID=?", (pres_id,))
    return jsonify({"message": "Prescription deleted"})


# ════════════════════════════════════════════════════════════
#  MEDICINES  (lookup list for prescription form)
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/medicines")
@login_required
def get_medicines():
    rows = query("SELECT MedicineID, Name, Unit FROM MEDICINE ORDER BY Name")
    return jsonify(rows)


# ════════════════════════════════════════════════════════════
#  BILLING
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/billing")
@login_required
def get_billing():
    status = request.args.get("status", "")
    search = request.args.get("search", "").strip()
    page   = int(request.args.get("page",  1))
    limit  = int(request.args.get("limit", 20))
    offset = (page - 1) * limit

    conditions, params = [], []
    if status:
        conditions.append("B.PaymentStatus = ?")
        params.append(status)
    if search:
        like = f"%{search}%"
        conditions.append("(P.FirstName LIKE ? OR P.LastName LIKE ?)")
        params += [like, like]

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    rows = query(
        f"""SELECT B.BillID, B.TotalAmount, B.PaymentStatus, B.BillDate,
                   P.FirstName + ' ' + P.LastName AS PatientName, P.PatientID,
                   B.AppointID,
                   D.FullName AS DoctorName
            FROM BILLING B
            JOIN PATIENT P ON B.PatientID = P.PatientID
            LEFT JOIN APPOINTMENT A ON B.AppointID = A.AppointID
            LEFT JOIN DOCTOR D ON A.DoctorID = D.DoctorID
            {where}
            ORDER BY B.BillDate DESC
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY""",
        params + [offset, limit]
    )
    for b in rows:
        if b.get("BillDate"): b["BillDate"] = str(b["BillDate"])[:10]
        if b.get("TotalAmount"): b["TotalAmount"] = float(b["TotalAmount"])

    total = query(
        f"SELECT COUNT(*) AS n FROM BILLING B JOIN PATIENT P ON B.PatientID=P.PatientID {where}",
        params, one=True
    )["n"]

    return jsonify({"bills": rows, "total": total})


@hospital_bp.route("/api/billing/<int:bill_id>/pay", methods=["PUT"])
@login_required
def pay_bill(bill_id):
    """Mark a bill as Paid (mirrors usp_ProcessPayment logic)."""
    execute("UPDATE BILLING SET PaymentStatus='Paid' WHERE BillID=?", (bill_id,))
    return jsonify({"message": "Marked as paid"})


# ════════════════════════════════════════════════════════════
#  ROOMS
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/rooms")
@login_required
def get_rooms():
    status = request.args.get("status", "")
    dept   = request.args.get("dept", "")

    conditions, params = [], []
    if status:
        conditions.append("R.Status = ?")
        params.append(status)
    if dept:
        conditions.append("R.DeptID = ?")
        params.append(dept)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    rows = query(
        f"""SELECT R.RoomID, R.RoomNumber, R.RoomType, R.Status,
                   D.DeptName AS Department, D.DeptID
            FROM ROOM R JOIN DEPARTMENT D ON R.DeptID = D.DeptID
            {where}
            ORDER BY R.RoomNumber""",
        params
    )
    return jsonify(rows)


@hospital_bp.route("/api/rooms/<int:room_id>/status", methods=["PUT"])
@login_required
def update_room_status(room_id):
    """Update room status (mirrors usp_UpdateRoomStatus — trigger logs the change automatically)."""
    data   = request.get_json()
    status = data.get("status", "")
    if status not in ("Vacant", "Occupied"):
        return jsonify({"error": "Status must be Vacant or Occupied"}), 400

    existing = query("SELECT 1 FROM ROOM WHERE RoomID=?", (room_id,), one=True)
    if not existing:
        return jsonify({"error": "Room not found"}), 404

    execute("UPDATE ROOM SET Status=? WHERE RoomID=?", (status, room_id))
    return jsonify({"message": f"Room marked as {status}"})


# ════════════════════════════════════════════════════════════
#  DEPARTMENTS
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/departments")
@login_required
def get_departments():
    """Uses the DepartmentOverview view logic."""
    rows = query(
        """SELECT D.DeptID, D.DeptName, D.Location,
                  COUNT(DISTINCT DR.DoctorID) AS DoctorCount,
                  COUNT(DISTINCT S.StaffID)   AS StaffCount,
                  COUNT(DISTINCT R.RoomID)    AS RoomCount,
                  SUM(CASE WHEN R.Status='Occupied' THEN 1 ELSE 0 END) AS OccupiedRooms
           FROM DEPARTMENT D
           LEFT JOIN DOCTOR DR ON DR.DeptID = D.DeptID
           LEFT JOIN STAFF   S ON S.DeptID  = D.DeptID
           LEFT JOIN ROOM    R ON R.DeptID  = D.DeptID
           GROUP BY D.DeptID, D.DeptName, D.Location
           ORDER BY D.DeptID"""
    )
    return jsonify(rows)


# ════════════════════════════════════════════════════════════
#  STAFF  (was in DB but no API routes existed)
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/staff")
@login_required
def get_staff():
    search = request.args.get("search", "").strip()
    dept   = request.args.get("dept", "")

    conditions, params = [], []
    if search:
        like = f"%{search}%"
        conditions.append("(S.FullName LIKE ? OR S.Role LIKE ?)")
        params += [like, like]
    if dept:
        conditions.append("S.DeptID = ?")
        params.append(dept)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    rows = query(
        f"""SELECT S.StaffID, S.FullName, S.Role,
                   D.DeptName AS Department, D.DeptID
            FROM STAFF S JOIN DEPARTMENT D ON S.DeptID = D.DeptID
            {where}
            ORDER BY S.FullName""",
        params
    )
    return jsonify(rows)


# ════════════════════════════════════════════════════════════
#  REPORTS  (using DB Views defined in 4.Views.sql)
# ════════════════════════════════════════════════════════════

@hospital_bp.route("/api/reports/doctor-workload")
@login_required
def report_doctor_workload():
    """Uses the DoctorWorkload view."""
    rows = query(
        """SELECT DoctorID, DoctorName, Specialization, DeptName,
                  TotalAppointments, CompletedAppointments, CancelledAppointments
           FROM DoctorWorkload
           ORDER BY TotalAppointments DESC"""
    )
    return jsonify(rows)


@hospital_bp.route("/api/reports/patient-safety-alerts")
@login_required
def report_patient_safety():
    """Uses the PatientSafetyAlerts view — patients with allergies or diagnoses."""
    rows = query(
        """SELECT PatientID, PatientName, Allergies, ChronicConditions,
                  EmergencyContact, EmergencyPhone
           FROM PatientSafetyAlerts
           ORDER BY PatientName"""
    )
    return jsonify(rows)


@hospital_bp.route("/api/reports/unbilled-appointments")
@login_required
def report_unbilled():
    """Appointments that have not been billed yet (from Queries.sql #19)."""
    rows = query(
        """SELECT A.AppointID, A.Date, A.Status,
                  P.FirstName + ' ' + P.LastName AS PatientName,
                  D.FullName AS DoctorName
           FROM APPOINTMENT A
           JOIN PATIENT P ON A.PatientID = P.PatientID
           JOIN DOCTOR  D ON A.DoctorID  = D.DoctorID
           WHERE A.AppointID NOT IN (SELECT DISTINCT AppointID FROM BILLING WHERE AppointID IS NOT NULL)
           ORDER BY A.Date DESC"""
    )
    for r in rows:
        if r.get("Date"): r["Date"] = str(r["Date"])[:10]
    return jsonify(rows)


@hospital_bp.route("/api/reports/department-revenue")
@login_required
def report_department_revenue():
    """Uses usp_DepartmentRevenueReport logic."""
    rows = query(
        """SELECT DE.DeptName,
                  ISNULL(SUM(B.TotalAmount), 0) AS TotalRevenue,
                  COUNT(B.BillID) AS BillCount
           FROM DEPARTMENT DE
           LEFT JOIN DOCTOR D   ON DE.DeptID   = D.DeptID
           LEFT JOIN APPOINTMENT A ON D.DoctorID = A.DoctorID
           LEFT JOIN BILLING B  ON A.AppointID  = B.AppointID AND B.PaymentStatus = 'Paid'
           GROUP BY DE.DeptName
           ORDER BY TotalRevenue DESC"""
    )
    for r in rows:
        r["TotalRevenue"] = float(r["TotalRevenue"] or 0)
    return jsonify(rows)


@hospital_bp.route("/api/reports/patients-no-appointment")
@login_required
def report_patients_no_apt():
    """Patients who have never booked an appointment (Queries.sql #4)."""
    rows = query(
        """SELECT P.PatientID, P.FirstName, P.LastName, P.Phone
           FROM PATIENT P
           WHERE P.PatientID NOT IN (SELECT DISTINCT PatientID FROM APPOINTMENT)
           ORDER BY P.PatientID"""
    )
    return jsonify(rows)


@hospital_bp.route("/api/reports/insurance-summary")
@login_required
def report_insurance_summary():
    """Uses PatientInsuranceDirectory view."""
    rows = query(
        """SELECT PatientID, PatientName, ProviderName, PolicyNumber, CoverageDetails
           FROM PatientInsuranceDirectory
           ORDER BY PatientName"""
    )
    return jsonify(rows)


# ════════════════════════════════════════════════════════════
#  USERS  (admin panel)
# ════════════════════════════════════════════════════════════
@hospital_bp.route("/api/users")
@login_required
def get_users():
    if session.get("role") != "admin":
        return jsonify({"error": "Admin only"}), 403
    rows = query("SELECT UserID, Username, FullName, Role, CreatedAt FROM USERS ORDER BY UserID")
    for r in rows:
        if r.get("CreatedAt"): r["CreatedAt"] = str(r["CreatedAt"])[:10]
    return jsonify(rows)


@hospital_bp.route("/api/users/<int:uid>", methods=["DELETE"])
@login_required
def delete_user(uid):
    if session.get("role") != "admin":
        return jsonify({"error": "Admin only"}), 403
    if uid == session["user_id"]:
        return jsonify({"error": "Cannot delete yourself"}), 400
    execute("DELETE FROM USERS WHERE UserID = ?", (uid,))
    return jsonify({"message": "User deleted"})
