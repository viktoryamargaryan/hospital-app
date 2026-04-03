-- ============================================================
--  INDEXES  (optimize query performance)
-- ============================================================

USE HospitalDB;
GO


-- ============================================================
-- TABLE: PATIENT
-- ============================================================

-- WHY: Frequent lookups by name in View_PatientAppointmentHistory & View_MedicalSafetyDashboard
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PATIENT_Name' AND object_id = OBJECT_ID('dbo.PATIENT'))
    DROP INDEX IX_PATIENT_Name ON PATIENT;
GO
CREATE NONCLUSTERED INDEX IX_PATIENT_Name
    ON PATIENT (LastName, FirstName)
    INCLUDE (Phone, DOB);
GO

-- WHY: Used in View 8 (PatientDemographics) to calculate age and life stages
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PATIENT_DOB' AND object_id = OBJECT_ID('dbo.PATIENT'))
    DROP INDEX IX_PATIENT_DOB ON PATIENT;
GO
CREATE NONCLUSTERED INDEX IX_PATIENT_DOB
    ON PATIENT (DOB)
    INCLUDE (FirstName, LastName);
GO


-- ============================================================
-- TABLE: DOCTOR
-- ============================================================

-- WHY: JOIN DOCTOR ? DEPARTMENT on DeptID (FK lookup)
--      Used in View 4 (DepartmentOverview) and View 6 (DoctorWorkload)
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DOCTOR_DeptID' AND object_id = OBJECT_ID('dbo.DOCTOR'))
    DROP INDEX IX_DOCTOR_DeptID ON DOCTOR;
GO
CREATE NONCLUSTERED INDEX IX_DOCTOR_DeptID
    ON DOCTOR (DeptID)
    INCLUDE (FullName, Specialization);
GO


-- ============================================================
-- TABLE: APPOINTMENT
-- ============================================================

-- WHY: Filter/Sort by date in DailySchedule (View 1) and Query 20
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_APPOINTMENT_Date' AND object_id = OBJECT_ID('dbo.APPOINTMENT'))
    DROP INDEX IX_APPOINTMENT_Date ON APPOINTMENT;
GO
CREATE NONCLUSTERED INDEX IX_APPOINTMENT_Date
    ON APPOINTMENT (Date DESC)
    INCLUDE (PatientID, DoctorID, Time, Status);
GO

-- WHY: JOIN APPOINTMENT ? PATIENT and DOCTOR (FK lookups)
-- TYPE: Nonclustered (Composite)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_APPOINTMENT_FKs' AND object_id = OBJECT_ID('dbo.APPOINTMENT'))
    DROP INDEX IX_APPOINTMENT_FKs ON APPOINTMENT;
GO
CREATE NONCLUSTERED INDEX IX_APPOINTMENT_FKs
    ON APPOINTMENT (PatientID, DoctorID)
    INCLUDE (Status, Date);
GO

-- WHY: Filter by status (Scheduled / Completed / Cancelled)
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_APPOINTMENT_Status' AND object_id = OBJECT_ID('dbo.APPOINTMENT'))
    DROP INDEX IX_APPOINTMENT_Status ON APPOINTMENT;
GO
CREATE NONCLUSTERED INDEX IX_APPOINTMENT_Status
    ON APPOINTMENT (Status)
    INCLUDE (Date, Time, PatientID);
GO


-- ============================================================
-- TABLE: BILLING
-- ============================================================

-- WHY: Filter Unpaid/Pending bills (View 5, Query 14)
-- TYPE: Filtered Nonclustered (Only indexes unpaid bills for speed)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BILLING_Pending' AND object_id = OBJECT_ID('dbo.BILLING'))
    DROP INDEX IX_BILLING_Pending ON BILLING;
GO
CREATE NONCLUSTERED INDEX IX_BILLING_Pending
    ON BILLING (PaymentStatus)
    INCLUDE (PatientID, TotalAmount, BillDate)
    WHERE PaymentStatus = 'Pending';
GO

-- WHY: JOIN BILLING ? PATIENT on PatientID (Query 15, 18)
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BILLING_PatientID' AND object_id = OBJECT_ID('dbo.BILLING'))
    DROP INDEX IX_BILLING_PatientID ON BILLING;
GO
CREATE NONCLUSTERED INDEX IX_BILLING_PatientID
    ON BILLING (PatientID)
    INCLUDE (TotalAmount, PaymentStatus, BillDate);
GO


-- ============================================================
-- TABLE: ROOM
-- ============================================================

-- WHY: Filter available rooms (View 7, Query 22)
-- TYPE: Filtered Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ROOM_Available' AND object_id = OBJECT_ID('dbo.ROOM'))
    DROP INDEX IX_ROOM_Available ON ROOM;
GO
CREATE NONCLUSTERED INDEX IX_ROOM_Available
    ON ROOM (Status)
    INCLUDE (RoomNumber, RoomType, DeptID)
    WHERE Status = 'Vacant';
GO


-- ============================================================
-- TABLE: MEDICAL_HISTORY
-- ============================================================

-- WHY: Lookup patient diagnosis and allergies (View 9, Query 9)
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MEDHISTORY_PatientID' AND object_id = OBJECT_ID('dbo.MEDICAL_HISTORY'))
    DROP INDEX IX_MEDHISTORY_PatientID ON MEDICAL_HISTORY;
GO
CREATE NONCLUSTERED INDEX IX_MEDHISTORY_PatientID
    ON MEDICAL_HISTORY (PatientID)
    INCLUDE (Diagnosis, Allergies);
GO


-- ============================================================
-- TABLE: INSURANCE
-- ============================================================

-- WHY: JOIN PATIENT ? INSURANCE (View 10, Query 16)
-- TYPE: Nonclustered
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_INSURANCE_PatientID' AND object_id = OBJECT_ID('dbo.INSURANCE'))
    DROP INDEX IX_INSURANCE_PatientID ON INSURANCE;
GO
CREATE NONCLUSTERED INDEX IX_INSURANCE_PatientID
    ON INSURANCE (PatientID)
    INCLUDE (ProviderName, PolicyNumber);
GO

-- ?? SEARCH INDEXES (speeds up patient/doctor search) ????????
-- Patient name search
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PATIENT_Name')
    CREATE INDEX IX_PATIENT_Name ON PATIENT(FirstName, LastName);

-- Patient phone search
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PATIENT_Phone')
    CREATE INDEX IX_PATIENT_Phone ON PATIENT(Phone);

-- Doctor name search
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DOCTOR_Name')
    CREATE INDEX IX_DOCTOR_Name ON DOCTOR(FullName);

-- Appointment date search
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_APPOINTMENT_Date')
    CREATE INDEX IX_APPOINTMENT_Date ON APPOINTMENT(Date);
GO

-- ?? ADD CreatedBy to PATIENT (tracks which user registered them) ??
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PATIENT') AND name = 'CreatedBy')
    ALTER TABLE PATIENT ADD CreatedBy INT NULL REFERENCES USERS(UserID);
GO

-- ?? ADD Gender + Age to PATIENT (required by new form) ??????
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PATIENT') AND name = 'Gender')
    ALTER TABLE PATIENT ADD Gender VARCHAR(10) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PATIENT') AND name = 'Age')
    ALTER TABLE PATIENT ADD Age INT NULL;
GO

PRINT 'Schema upgrade complete. Default admin: username=admin, password=Admin1234';
GO




-- ============================================================
-- VERIFY ALL INDEXES CREATED
-- ============================================================
SELECT
    t.name          AS TableName,
    i.name          AS IndexName,
    i.type_desc     AS IndexType,
    i.is_unique     AS IsUnique,
    i.has_filter    AS IsFiltered,
    i.filter_definition AS FilterCondition
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.type > 0 -- exclude heaps
  AND t.name IN (
      'PATIENT', 'DOCTOR', 'APPOINTMENT', 
      'BILLING', 'ROOM', 'MEDICAL_HISTORY', 
      'INSURANCE', 'DEPARTMENT'
  )
ORDER BY t.name, i.name;
GO