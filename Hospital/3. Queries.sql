-- ============================================================
-- HospitalDB - DQL Queries (T-SQL / SQL Server)
-- ============================================================

USE HospitalDB;
GO

-- ============================================================
-- PATIENTS & APPOINTMENTS
-- ============================================================

-- 1. Get all patients who have had at least one appointment
--    ? PatientID (APPOINTMENT)
-- ============================================================
SELECT DISTINCT
    P.PatientID,
    P.FirstName,
    P.LastName,
    P.Phone
FROM PATIENT P
INNER JOIN APPOINTMENT A ON P.PatientID = A.PatientID;
GO

-- 2. Get all appointments with status 'Scheduled'
--    ? Status = 'Scheduled' (APPOINTMENT)
-- ============================================================
SELECT
    AppointID,
    PatientID,
    DoctorID,
    Date,
    Time
FROM APPOINTMENT
WHERE Status = 'Scheduled';
GO

-- 3. Get the Date and Time of appointments for PatientID = 5
--    ? Date, Time (? PatientID = 5 (APPOINTMENT))
-- ============================================================
SELECT
    Date,
    Time
FROM APPOINTMENT
WHERE PatientID = 5;
GO

-- 4. Get all patients who have NEVER booked an appointment
--    ? PatientID (PATIENT) ? ? PatientID (APPOINTMENT)
-- ============================================================
SELECT
    P.PatientID,
    P.FirstName,
    P.LastName
FROM PATIENT P
WHERE P.PatientID NOT IN (
    SELECT DISTINCT PatientID FROM APPOINTMENT
);
GO

-- 5. Get full details of appointments along with the patient name
--    PATIENT ? PATIENT.PatientID = APPOINTMENT.PatientID APPOINTMENT
-- ============================================================
SELECT
    P.FirstName,
    P.LastName,
    A.AppointID,
    A.Date,
    A.Time,
    A.Status
FROM PATIENT P
INNER JOIN APPOINTMENT A ON P.PatientID = A.PatientID
ORDER BY A.Date DESC;
GO

-- 6. Get all prescribed medicines for PrescriptionID = 10
--    ? PrescriptionID = 10 (PRESCRIPTION_CONTAINS)
-- ============================================================
SELECT
    PrescriptionID,
    MedicineID,
    Dosage
FROM PRESCRIPTION_CONTAINS
WHERE PrescriptionID = 10;
GO

-- 7. Get the Dosage and Date for all prescriptions of MedicineID = 3
--    ? Dosage, DateIssued (PRESCRIPTION ? PRESCRIPTION_CONTAINS ? MedicineID=3)
-- ============================================================
SELECT
    PC.Dosage,
    P.DateIssued
FROM PRESCRIPTION_CONTAINS PC
INNER JOIN PRESCRIPTION P ON PC.PrescriptionID = P.PrescriptionID
WHERE PC.MedicineID = 3;
GO

-- ============================================================
-- DOCTORS & DEPARTMENTS
-- ============================================================

-- 8. Get all doctors belonging to DepartmentID = 2
--    ? DoctorID, FullName (? DeptID = 2 (DOCTOR))
-- ============================================================
SELECT
    DoctorID,
    FullName,
    Specialization,
    LicenseNumber
FROM DOCTOR
WHERE DeptID = 2;
GO

-- 9. Get all medical history records with a 'Diabetes' diagnosis
--    ? Diagnosis LIKE '%Diabetes%' (MEDICAL_HISTORY)
-- ============================================================
SELECT
    HistoryID,
    PatientID,
    Diagnosis,
    Allergies
FROM MEDICAL_HISTORY
WHERE Diagnosis LIKE '%Diabetes%';
GO

-- 10. Get names and roles of all staff in 'Cardiology'
--     ? FullName, Role (STAFF ? DEPARTMENT.DeptName = 'Cardiology')
-- ============================================================
SELECT
    S.FullName,
    S.Role
FROM STAFF S
INNER JOIN DEPARTMENT D ON S.DeptID = D.DeptID
WHERE D.DeptName = 'Cardiology';
GO

-- 11. Get all doctors with their department names
--     DOCTOR ? DOCTOR.DeptID = DEPARTMENT.DeptID DEPARTMENT
-- ============================================================
SELECT
    D.FullName AS DoctorName,
    D.Specialization,
    DEP.DeptName,
    DEP.Location
FROM DOCTOR D
INNER JOIN DEPARTMENT DEP ON D.DeptID = DEP.DeptID;
GO

-- 12. Get all departments located in 'Building A'
--     ? Location = 'Building A' (DEPARTMENT)
-- ============================================================
SELECT
    DeptID,
    DeptName
FROM DEPARTMENT
WHERE Location = 'Building A';
GO

-- 13. Get all active prescriptions with Patient and Doctor details
--     PRESCRIPTION ? APPOINTMENT ? PATIENT ? DOCTOR
-- ============================================================
SELECT
    PR.PrescriptionID,
    P.FirstName + ' ' + P.LastName AS PatientName,
    D.FullName AS DoctorName,
    PR.DateIssued
FROM PRESCRIPTION PR
INNER JOIN APPOINTMENT A ON PR.AppointID = A.AppointID
INNER JOIN PATIENT P ON A.PatientID = P.PatientID
INNER JOIN DOCTOR D ON A.DoctorID = D.DoctorID;
GO

-- ============================================================
-- BILLING & INSURANCE
-- ============================================================

-- 14. Get all bills with status 'Pending'
--     ? PaymentStatus = 'Pending' (BILLING)
-- ============================================================
SELECT
    BillID,
    PatientID,
    TotalAmount,
    BillDate
FROM BILLING
WHERE PaymentStatus = 'Pending';
GO

-- 15. Get all billing records along with insurance provider names
--     BILLING ? INSURANCE
-- ============================================================
SELECT
    B.BillID,
    B.TotalAmount,
    I.ProviderName,
    I.PolicyNumber
FROM BILLING B
INNER JOIN INSURANCE I ON B.PatientID = I.PatientID;
GO

-- 16. Get all insurance policies for a specific PatientID = 7
--     ? PatientID = 7 (INSURANCE)
-- ============================================================
SELECT
    InsuranceID,
    ProviderName,
    PolicyNumber,
    CoverageDetails
FROM INSURANCE
WHERE PatientID = 7;
GO

-- 17. Get all bills where the amount is greater than 500
--     ? TotalAmount > 500 (BILLING)
-- ============================================================
SELECT
    BillID,
    PatientID,
    TotalAmount,
    PaymentStatus
FROM BILLING
WHERE TotalAmount > 500;
GO

-- 18. Get patients who have 'Paid' bills and an active 'Premium' insurance
--     ? PatientID (? PaymentStatus='Paid' (BILLING)) ? ? PatientID (INSURANCE)
-- ============================================================
SELECT DISTINCT
    P.FirstName,
    P.LastName,
    B.TotalAmount,
    I.ProviderName
FROM PATIENT P
INNER JOIN BILLING B ON P.PatientID = B.PatientID
INNER JOIN INSURANCE I ON P.PatientID = I.PatientID
WHERE B.PaymentStatus = 'Paid';
GO

-- 19. Get all appointments that have NOT been billed yet
--     ? AppointID (APPOINTMENT) ? ? AppointID (BILLING)
-- ============================================================
SELECT
    A.AppointID,
    A.Date,
    A.PatientID
FROM APPOINTMENT A
WHERE A.AppointID NOT IN (
    SELECT DISTINCT AppointID FROM BILLING
);
GO

-- 20. Get full billing details including appointment date and doctor
--     BILLING ? APPOINTMENT ? DOCTOR
-- ============================================================
SELECT
    B.BillID,
    B.TotalAmount,
    A.Date AS ServiceDate,
    D.FullName AS AttendingDoctor
FROM BILLING B
INNER JOIN APPOINTMENT A ON B.AppointID = A.AppointID
INNER JOIN DOCTOR D ON A.DoctorID = D.DoctorID;
GO

-- ============================================================
-- FACILITIES & EMERGENCY
-- ============================================================

-- 21. Get all emergency contacts for PatientID = 3
--     ? PatientID = 3 (EMERGENCY_CONTACT)
-- ============================================================
SELECT
    ContactName,
    Relationship,
    Phone
FROM EMERGENCY_CONTACT
WHERE PatientID = 3;
GO

-- 22. Get all rooms that are currently 'Vacant'
--     ? Status = 'Vacant' (ROOM)
-- ============================================================
SELECT
    RoomNumber,
    RoomType,
    DeptID
FROM ROOM
WHERE Status = 'Vacant';
GO

-- 23. Get all patients who have medical history entries
--     PATIENT ? MEDICAL_HISTORY
-- ============================================================
SELECT DISTINCT
    P.PatientID,
    P.FirstName,
    P.LastName,
    MH.Diagnosis
FROM PATIENT P
INNER JOIN MEDICAL_HISTORY MH ON P.PatientID = MH.PatientID;
GO

-- 24. Get list of all unique PatientIDs from both Appointments and Emergency Contacts
--     ? PatientID (APPOINTMENT) ? ? PatientID (EMERGENCY_CONTACT)
-- ============================================================
SELECT PatientID FROM APPOINTMENT
UNION
SELECT PatientID FROM EMERGENCY_CONTACT;
GO

-- 25. Get patients who have both an Insurance policy AND a Medical History
--     ? PatientID (INSURANCE) ? ? PatientID (MEDICAL_HISTORY)
-- ============================================================
SELECT PatientID FROM INSURANCE
INTERSECT
SELECT PatientID FROM MEDICAL_HISTORY;
GO

-- 26. Get room details along with the department they belong to
--     ROOM ? DEPARTMENT
-- ============================================================
SELECT
    R.RoomNumber,
    R.RoomType,
    R.Status,
    D.DeptName,
    D.Location
FROM ROOM R
INNER JOIN DEPARTMENT D ON R.DeptID = D.DeptID
ORDER BY D.DeptName;
GO

-- 27. Get all patients with allergies listed in their medical history
--     ? Allergies IS NOT NULL (MEDICAL_HISTORY)
-- ============================================================
SELECT
    P.FirstName,
    P.LastName,
    MH.Allergies
FROM PATIENT P
INNER JOIN MEDICAL_HISTORY MH ON P.PatientID = MH.PatientID
WHERE MH.Allergies IS NOT NULL AND MH.Allergies <> 'None';
GO