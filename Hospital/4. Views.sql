-- ============================================================
--  VIEWS  (DQL stored as views)
-- ============================================================

-- Drop views
USE HospitalDB;
GO
IF OBJECT_ID('DailySchedule',       'V') IS NOT NULL DROP VIEW DailySchedule;
IF OBJECT_ID('PatientMedicalSummary','V') IS NOT NULL DROP VIEW PatientMedicalSummary;
IF OBJECT_ID('BillingSummary',       'V') IS NOT NULL DROP VIEW BillingSummary;
IF OBJECT_ID('DepartmentOverview',   'V') IS NOT NULL DROP VIEW DepartmentOverview;
IF OBJECT_ID('UnpaidBills',          'V') IS NOT NULL DROP VIEW UnpaidBills;
IF OBJECT_ID('DoctorWorkload',       'V') IS NOT NULL DROP VIEW DoctorWorkload;
IF OBJECT_ID('AvailableRooms','V') IS NOT NULL DROP VIEW AvailableRooms;
IF OBJECT_ID('PatientDemographics',       'V') IS NOT NULL DROP VIEW PatientDemographics;
IF OBJECT_ID('PatientSafetyAlerts',   'V') IS NOT NULL DROP VIEW PatientSafetyAlerts;
IF OBJECT_ID('PatientInsuranceDirectory',          'V') IS NOT NULL DROP VIEW PatientInsuranceDirectory;
GO

-- View 1: Daily appointment schedule
CREATE VIEW DailySchedule AS
SELECT
    A.Date,
    A.Time,
    P.FirstName + ' ' + P.LastName AS Patient,
    D.FullName                      AS Doctor,
    A.Status
FROM APPOINTMENT A
JOIN PATIENT P ON A.PatientID = P.PatientID
JOIN DOCTOR  D ON A.DoctorID  = D.DoctorID;
GO

-- View 2: Patient prescription summary
CREATE VIEW PatientMedicalSummary AS
SELECT
    P.FirstName,
    P.LastName,
    M.Name       AS Medicine,
    C.Dosage,
    Pr.DateIssued
FROM PATIENT P
JOIN APPOINTMENT          A  ON P.PatientID      = A.PatientID
JOIN PRESCRIPTION         Pr ON A.AppointID      = Pr.AppointID
JOIN PRESCRIPTION_CONTAINS C ON Pr.PrescriptionID = C.PrescriptionID
JOIN MEDICINE             M  ON C.MedicineID      = M.MedicineID;
GO

-- View 3: Full billing summary with doctor info
CREATE VIEW BillingSummary AS
SELECT
    P.PatientID,
    P.FirstName + ' ' + P.LastName AS PatientName,
    B.BillID,
    B.TotalAmount,
    B.PaymentStatus,
    B.BillDate,
    A.Date     AS AppointmentDate,
    D.FullName AS DoctorName
FROM BILLING     B
JOIN PATIENT     P ON B.PatientID = P.PatientID
JOIN APPOINTMENT A ON B.AppointID = A.AppointID
JOIN DOCTOR      D ON A.DoctorID  = D.DoctorID;
GO

-- View 4: Department capacity overview
CREATE VIEW DepartmentOverview AS
SELECT
    D.DeptID,
    D.DeptName,
    D.Location,
    COUNT(DISTINCT DR.DoctorID) AS DoctorCount,
    COUNT(DISTINCT S.StaffID)   AS StaffCount,
    COUNT(DISTINCT R.RoomID)    AS RoomCount,
    SUM(CASE WHEN R.Status = 'Occupied' THEN 1 ELSE 0 END) AS OccupiedRooms
FROM DEPARTMENT D
LEFT JOIN DOCTOR DR ON DR.DeptID = D.DeptID
LEFT JOIN STAFF   S ON S.DeptID  = D.DeptID
LEFT JOIN ROOM    R ON R.DeptID  = D.DeptID
GROUP BY D.DeptID, D.DeptName, D.Location;
GO

-- View 5: Unpaid bills with emergency contact
CREATE VIEW UnpaidBills AS
SELECT
    B.BillID,
    P.FirstName + ' ' + P.LastName AS PatientName,
    P.Phone,
    B.TotalAmount,
    B.BillDate,
    EC.ContactName  AS EmergencyContact,
    EC.Phone        AS EmergencyPhone
FROM BILLING              B
JOIN PATIENT              P  ON B.PatientID  = P.PatientID
LEFT JOIN EMERGENCY_CONTACT EC ON EC.PatientID = P.PatientID
WHERE B.PaymentStatus = 'Pending';
GO

-- View 6: Doctor Performance & Workload
CREATE VIEW DoctorWorkload AS
SELECT 
    D.DoctorID,
    D.FullName AS DoctorName,
    D.Specialization,
    DEP.DeptName,
    COUNT(A.AppointID) AS TotalAppointments,
    SUM(CASE WHEN A.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedAppointments,
    SUM(CASE WHEN A.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledAppointments
FROM DOCTOR D
JOIN DEPARTMENT DEP ON D.DeptID = DEP.DeptID
LEFT JOIN APPOINTMENT A ON D.DoctorID = A.DoctorID
GROUP BY D.DoctorID, D.FullName, D.Specialization, DEP.DeptName;
GO

-- View 7: Available Rooms by Department
CREATE VIEW AvailableRooms AS
SELECT 
    R.RoomNumber,
    R.RoomType,
    DEP.DeptName,
    DEP.Location
FROM ROOM R
JOIN DEPARTMENT DEP ON R.DeptID = DEP.DeptID
WHERE R.Status = 'Vacant';
GO

-- View 8: Patient Demographics & Age Groups
CREATE VIEW PatientDemographics AS
SELECT 
    PatientID,
    FirstName + ' ' + LastName AS FullName,
    DOB,
    DATEDIFF(YEAR, DOB, GETDATE()) AS Age,
    CASE 
        WHEN DATEDIFF(YEAR, DOB, GETDATE()) < 18 THEN 'Pediatric'
        WHEN DATEDIFF(YEAR, DOB, GETDATE()) BETWEEN 18 AND 64 THEN 'Adult'
        ELSE 'Senior'
    END AS AgeGroup,
    Address
FROM PATIENT;
GO

-- View 9: Comprehensive Medical Alert View
CREATE VIEW PatientSafetyAlerts AS
SELECT 
    P.PatientID,
    P.FirstName + ' ' + P.LastName AS PatientName,
    MH.Allergies,
    MH.Diagnosis AS ChronicConditions,
    EC.ContactName AS EmergencyContact,
    EC.Phone AS EmergencyPhone
FROM PATIENT P
JOIN MEDICAL_HISTORY MH ON P.PatientID = MH.PatientID
LEFT JOIN EMERGENCY_CONTACT EC ON P.PatientID = EC.PatientID
WHERE MH.Allergies IS NOT NULL OR MH.Diagnosis IS NOT NULL;
GO

-- View 10: Insurance Coverage Summary
CREATE VIEW PatientInsuranceDirectory AS
SELECT 
    P.PatientID,
    P.FirstName + ' ' + P.LastName AS PatientName,
    I.ProviderName,
    I.PolicyNumber,
    I.CoverageDetails
FROM PATIENT P
INNER JOIN INSURANCE I ON P.PatientID = I.PatientID;
GO