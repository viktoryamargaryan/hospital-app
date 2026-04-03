# 🏥 MedCore — Hospital Management System v2

## Project Structure
```
hospital_v2/
├── app.py                    ← Main Flask app (START HERE)
├── database.py               ← DB connection (edit server name here)
├── requirements.txt          ← Python dependencies
├── 00_schema_upgrade.sql     ← Run this in SSMS FIRST
│
├── routes/
│   ├── __init__.py
│   ├── auth.py               ← Login / logout / register users
│   ├── patients.py           ← Patient CRUD + search
│   └── hospital.py           ← Doctors, appointments, billing, rooms
│
└── templates/
    ├── login.html            ← Welcome / sign-in page
    └── dashboard.html        ← Full hospital dashboard
```

---

## ⚡ Setup (4 Steps)

### Step 1 — Run the SQL upgrade in SSMS
Open SQL Server Management Studio, connect to your database, then open and run:
```
00_schema_upgrade.sql
```
This adds: USERS table, Gender/Age columns, search indexes.

### Step 2 — Install Python packages
```bash
pip install -r requirements.txt
```
Or manually:
```bash
pip install flask flask-cors pyodbc werkzeug
```

### Step 3 — Set your database connection
Open `database.py` and update lines 9-10:
```python
SERVER   = r"localhost\SQLEXPRESS"   # your SQL Server name
DATABASE = "HospitalDB"              # your database name
```
**How to find your server name:** Open SSMS → the name shown in the connection dialog is your server name.

### Step 4 — Start the app
```bash
python app.py
```
Open browser: **http://127.0.0.1:5000**

**Default login:** username: `admin`  password: `Admin1234`

---

## 🔐 Authentication System

| Role      | Can Do                                          |
|-----------|-------------------------------------------------|
| Admin     | Full access + create users + delete patients    |
| Assistant | View all data, register patients, book apts     |

### Create a new assistant account:
1. Log in as admin
2. Go to sidebar → Users
3. Click "+ Add User"

---

## ✅ Features

### Dashboard
- 6 clickable stat cards (patients, doctors, appointments, pending bills, departments, vacant rooms)
- Each card navigates to its section
- Recent appointments table

### Patients
- Full table with pagination (15 per page)
- **Search** by name, phone, or patient ID (debounced, 300ms)
- **Add Patient form**: First name, Last name, Age, Gender, DOB, Phone, Address
- Admin-only delete

### Doctors
- Full list with specialization and department
- Search by name or specialization

### Appointments
- Filter chips: All / Scheduled / Completed / Cancelled
- Search by patient or doctor name
- Book new appointment (patient + doctor dropdowns)
- Mark as Completed or Cancelled inline

### Billing
- Filter chips: All / Pending / Paid
- Mark bill as Paid in one click

### Rooms
- Filter by Vacant / Occupied

### Departments
- Shows doctor count per department

### Users (Admin only)
- See all system users
- Add new assistant/admin accounts
- Delete users (can't delete yourself)

---

## 🐛 Troubleshooting

**"pyodbc.InterfaceError: ('IM002', ...)"**
→ Install ODBC Driver 17: https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

**"Login required" on all API calls**
→ Make sure your browser sends cookies (`credentials: 'include'` is already set)

**"Cannot reach backend" in browser**
→ `python app.py` must be running in a terminal. Keep it open.

**Password for admin doesn't work**
→ Re-run `00_schema_upgrade.sql` which resets it to `Admin1234`
   Or in SSMS run:
```sql
UPDATE USERS SET Password = 'pbkdf2:sha256:260000$...' WHERE Username='admin'
```
   Better: log in with Admin1234 then change it through the API.

---

## 📤 Push to GitHub
```bash
cd hospital_v2
git init
git add .
git commit -m "Hospital Management System v2 - Full Stack with Auth"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/hospital-management.git
git push -u origin main
```
