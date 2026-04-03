-- ============================================================
-- Hospital Patient Management System
-- ============================================================

-- ============================================================
-- CREATE & SELECT DATABASE
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'HospitalDB')
    CREATE DATABASE HospitalDB;
GO

USE HospitalDB;
GO

-- ============================================================
--  SECTION 1 – DDL  
-- ============================================================

-- Drop tables (child ? parent order)
IF OBJECT_ID('dbo.USERS', 'U') IS NOT NULL DROP TABLE USERS;
IF OBJECT_ID('ROOM_AUDIT',          'U') IS NOT NULL DROP TABLE ROOM_AUDIT;
IF OBJECT_ID('PRESCRIPTION_CONTAINS','U') IS NOT NULL DROP TABLE PRESCRIPTION_CONTAINS;
IF OBJECT_ID('PRESCRIPTION',        'U') IS NOT NULL DROP TABLE PRESCRIPTION;
IF OBJECT_ID('BILLING',             'U') IS NOT NULL DROP TABLE BILLING;
IF OBJECT_ID('APPOINTMENT',         'U') IS NOT NULL DROP TABLE APPOINTMENT;
IF OBJECT_ID('MEDICAL_HISTORY',     'U') IS NOT NULL DROP TABLE MEDICAL_HISTORY;
IF OBJECT_ID('INSURANCE',           'U') IS NOT NULL DROP TABLE INSURANCE;
IF OBJECT_ID('EMERGENCY_CONTACT',   'U') IS NOT NULL DROP TABLE EMERGENCY_CONTACT;
IF OBJECT_ID('ROOM',                'U') IS NOT NULL DROP TABLE ROOM;
IF OBJECT_ID('STAFF',               'U') IS NOT NULL DROP TABLE STAFF;
IF OBJECT_ID('PATIENT',             'U') IS NOT NULL DROP TABLE PATIENT;
IF OBJECT_ID('DOCTOR',              'U') IS NOT NULL DROP TABLE DOCTOR;
IF OBJECT_ID('MEDICINE',            'U') IS NOT NULL DROP TABLE MEDICINE;
IF OBJECT_ID('DEPARTMENT',          'U') IS NOT NULL DROP TABLE DEPARTMENT;
GO


--  DEPARTMENT 
CREATE TABLE DEPARTMENT (
    DeptID   INT          PRIMARY KEY,
    DeptName VARCHAR(100) NOT NULL,
    Location VARCHAR(100)
);
GO

-- DOCTOR 
CREATE TABLE DOCTOR (
    DoctorID       INT          PRIMARY KEY,
    FullName       VARCHAR(100) NOT NULL,
    Specialization VARCHAR(100),
    LicenseNumber  VARCHAR(50)  UNIQUE,
    DeptID         INT,
    FOREIGN KEY (DeptID) REFERENCES DEPARTMENT(DeptID)
);
GO

-- PATIENT 
CREATE TABLE PATIENT (
    PatientID INT          PRIMARY KEY,
    FirstName VARCHAR(50)  NOT NULL,
    LastName  VARCHAR(50)  NOT NULL,
    DOB       DATE,
    Phone     VARCHAR(20),
    Address   VARCHAR(255)
);
GO

--  APPOINTMENT
CREATE TABLE APPOINTMENT (
    AppointID INT         PRIMARY KEY,
    Date      DATE        NOT NULL,
    Time      TIME        NOT NULL,
    Status    VARCHAR(20) DEFAULT 'Scheduled',
    PatientID INT,
    DoctorID  INT,
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID),
    FOREIGN KEY (DoctorID)  REFERENCES DOCTOR(DoctorID)
);
GO

--  BILLING 
CREATE TABLE BILLING (
    BillID        INT             PRIMARY KEY,
    PatientID     INT,
    AppointID     INT,
    TotalAmount   DECIMAL(10,2),
    PaymentStatus VARCHAR(20)     DEFAULT 'Pending',
    BillDate      DATE,
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID),
    FOREIGN KEY (AppointID) REFERENCES APPOINTMENT(AppointID)
);
GO

-- MEDICINE 
CREATE TABLE MEDICINE (
    MedicineID INT          PRIMARY KEY,
    Name       VARCHAR(100) NOT NULL,
    Unit       VARCHAR(50)
);
GO

-- PRESCRIPTION 
CREATE TABLE PRESCRIPTION (
    PrescriptionID INT  PRIMARY KEY,
    DateIssued     DATE NOT NULL,
    AppointID      INT,
    FOREIGN KEY (AppointID) REFERENCES APPOINTMENT(AppointID)
);
GO

-- PRESCRIPTION_CONTAINS  
CREATE TABLE PRESCRIPTION_CONTAINS (
    PrescriptionID INT,
    MedicineID     INT,
    Dosage         VARCHAR(50),
    PRIMARY KEY (PrescriptionID, MedicineID),
    FOREIGN KEY (PrescriptionID) REFERENCES PRESCRIPTION(PrescriptionID),
    FOREIGN KEY (MedicineID)     REFERENCES MEDICINE(MedicineID)
);
GO

--  EMERGENCY_CONTACT 
CREATE TABLE EMERGENCY_CONTACT (
    ContactID    INT          PRIMARY KEY,
    PatientID    INT,
    ContactName  VARCHAR(100),
    Relationship VARCHAR(50),
    Phone        VARCHAR(20),
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID)
);
GO

--  INSURANCE 
CREATE TABLE INSURANCE (
    InsuranceID     INT          PRIMARY KEY,
    PatientID       INT,
    ProviderName    VARCHAR(100),
    PolicyNumber    VARCHAR(50)  UNIQUE,
    CoverageDetails VARCHAR(MAX),
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID)
);
GO

-- MEDICAL_HISTORY 
CREATE TABLE MEDICAL_HISTORY (
    HistoryID      INT          PRIMARY KEY,
    PatientID      INT,
    Diagnosis      VARCHAR(255),
    SurgeryHistory VARCHAR(255),
    Allergies      VARCHAR(255),
    FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID)
);
GO

-- ROOM 
CREATE TABLE ROOM (
    RoomID     INT         PRIMARY KEY,
    RoomNumber VARCHAR(10) NOT NULL,
    RoomType   VARCHAR(50),
    Status     VARCHAR(20) DEFAULT 'Vacant',
    DeptID     INT,
    FOREIGN KEY (DeptID) REFERENCES DEPARTMENT(DeptID)
);
GO

--  STAFF
CREATE TABLE STAFF (
    StaffID  INT          PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Role     VARCHAR(50),
    DeptID   INT,
    FOREIGN KEY (DeptID) REFERENCES DEPARTMENT(DeptID)
);
GO

--  ROOM_AUDIT  (used by trigger) 
CREATE TABLE ROOM_AUDIT (
    AuditID   INT IDENTITY(1,1) PRIMARY KEY,
    RoomID    INT,
    OldStatus VARCHAR(20),
    NewStatus VARCHAR(20),
    ChangedAt DATETIME DEFAULT GETDATE()
);
GO
-- ?? USERS TABLE (for login system) ??????????????????????????


CREATE TABLE USERS (
    UserID      INT IDENTITY(1,1) PRIMARY KEY,
    Username    VARCHAR(50)  NOT NULL UNIQUE,
    Password    VARCHAR(255) NOT NULL,      -- stores hashed password
    FullName    VARCHAR(100) NOT NULL,
    Role        VARCHAR(20)  NOT NULL DEFAULT 'assistant', -- 'admin' or 'assistant'
    CreatedAt   DATETIME     DEFAULT GETDATE()
);
GO

