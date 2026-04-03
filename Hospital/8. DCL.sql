-- ============================================================
-- Hospital Management System - ACCESS CONTROL (DCL)
-- SQL Server GRANT / REVOKE / DENY statements
-- ============================================================

USE HospitalDB;
GO

-- ============================================================
-- STEP 1: CLEANUP (Drop Users and Roles to allow a clean re-run)
-- We drop users first because roles cannot be dropped if they have members.
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'user_doctor')  DROP USER user_doctor;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'user_nurse')   DROP USER user_nurse;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'user_billing') DROP USER user_billing;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'user_admin')   DROP USER user_admin;
GO

IF DATABASE_PRINCIPAL_ID('hospital_doctor')  IS NOT NULL DROP ROLE hospital_doctor;
IF DATABASE_PRINCIPAL_ID('hospital_nurse')   IS NOT NULL DROP ROLE hospital_nurse;
IF DATABASE_PRINCIPAL_ID('hospital_billing') IS NOT NULL DROP ROLE hospital_billing;
IF DATABASE_PRINCIPAL_ID('hospital_admin')   IS NOT NULL DROP ROLE hospital_admin;
GO

-- ============================================================
-- STEP 2: CREATE DATABASE ROLES
-- ============================================================

CREATE ROLE hospital_doctor;
CREATE ROLE hospital_nurse;
CREATE ROLE hospital_billing;
CREATE ROLE hospital_admin;
GO

-- ============================================================
-- STEP 3: CREATE LOGINS & DATABASE USERS
-- ============================================================

-- ?? Doctor Login & User ??
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_doc')
    CREATE LOGIN login_doc WITH PASSWORD = 'Doc$SecurePass123';
GO
CREATE USER user_doctor FOR LOGIN login_doc;
GO

-- ?? Nurse Login & User ??
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_nurse')
    CREATE LOGIN login_nurse WITH PASSWORD = 'Nurse$Pass!2026';
GO
CREATE USER user_nurse FOR LOGIN login_nurse;
GO

-- ?? Billing Login & User ??
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_billing')
    CREATE LOGIN login_billing WITH PASSWORD = 'Bill$Pay!2026';
GO
CREATE USER user_billing FOR LOGIN login_billing;
GO

-- ?? Admin Login & User ??
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_h_admin')
    CREATE LOGIN login_h_admin WITH PASSWORD = 'Hospital$Admin#1';
GO
CREATE USER user_admin FOR LOGIN login_h_admin;
GO

-- ============================================================
-- STEP 4: ASSIGN USERS TO ROLES
-- ============================================================

ALTER ROLE hospital_doctor  ADD MEMBER user_doctor;
ALTER ROLE hospital_nurse   ADD MEMBER user_nurse;
ALTER ROLE hospital_billing ADD MEMBER user_billing;
ALTER ROLE hospital_admin   ADD MEMBER user_admin;
GO

-- ============================================================
-- STEP 5: GRANT PERMISSIONS — hospital_doctor
-- ============================================================

-- Access to Clinical Data
GRANT SELECT ON dbo.PATIENT TO hospital_doctor;
GRANT SELECT, INSERT, UPDATE ON dbo.MEDICAL_HISTORY TO hospital_doctor;
GRANT SELECT, INSERT, UPDATE ON dbo.APPOINTMENT TO hospital_doctor;
GRANT SELECT, INSERT ON dbo.PRESCRIPTION TO hospital_doctor;
GRANT SELECT, INSERT ON dbo.PRESCRIPTION_CONTAINS TO hospital_doctor;

-- Execution of Stored Procedures
GRANT EXECUTE ON dbo.usp_BookAppointment TO hospital_doctor;
GRANT EXECUTE ON dbo.usp_GetPatientFullHistory TO hospital_doctor;
GRANT EXECUTE ON dbo.usp_IssuePrescription TO hospital_doctor;

-- Explicitly block financial data
DENY SELECT, INSERT, UPDATE ON dbo.BILLING TO hospital_doctor;
GO

-- ============================================================
-- STEP 6: GRANT PERMISSIONS — hospital_nurse
-- ============================================================

GRANT SELECT ON dbo.PATIENT TO hospital_nurse;
GRANT SELECT ON dbo.MEDICAL_HISTORY TO hospital_nurse;
GRANT SELECT, UPDATE ON dbo.ROOM TO hospital_nurse;
GRANT SELECT ON dbo.EMERGENCY_CONTACT TO hospital_nurse;

GRANT EXECUTE ON dbo.usp_UpdateRoomStatus TO hospital_nurse;
GRANT EXECUTE ON dbo.usp_DischargePatient TO hospital_nurse;

-- Nurses can view but not change diagnoses
DENY UPDATE ON dbo.MEDICAL_HISTORY TO hospital_nurse;
GO

-- ============================================================
-- STEP 7: GRANT PERMISSIONS — hospital_billing
-- ============================================================

GRANT SELECT ON dbo.PATIENT TO hospital_billing;
GRANT SELECT, INSERT, UPDATE ON dbo.BILLING TO hospital_billing;
GRANT SELECT ON dbo.INSURANCE TO hospital_billing;

GRANT EXECUTE ON dbo.usp_GenerateBill TO hospital_billing;
GRANT EXECUTE ON dbo.usp_ProcessPayment TO hospital_billing;
GRANT EXECUTE ON dbo.usp_DepartmentRevenueReport TO hospital_billing;

-- Block clinical notes for privacy
DENY SELECT ON dbo.MEDICAL_HISTORY TO hospital_billing;
DENY SELECT ON dbo.PRESCRIPTION TO hospital_billing;
GO

-- ============================================================
-- STEP 8: GRANT PERMISSIONS — hospital_admin
-- ============================================================

-- Full access to all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.PATIENT TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.DOCTOR TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.DEPARTMENT TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.ROOM TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.BILLING TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.MEDICAL_HISTORY TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.INSURANCE TO hospital_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.EMERGENCY_CONTACT TO hospital_admin;

-- Full execute access
GRANT EXECUTE TO hospital_admin;
GO

-- ============================================================
-- STEP 9: VERIFICATION
-- ============================================================

SELECT 
    pr.name AS RoleName, 
    pe.state_desc AS PermissionState, 
    pe.permission_name AS Permission, 
    COALESCE(OBJECT_NAME(pe.major_id), pe.class_desc) AS ObjectName
FROM sys.database_permissions pe
INNER JOIN sys.database_principals pr ON pe.grantee_principal_id = pr.principal_id
WHERE pr.name IN ('hospital_doctor', 'hospital_nurse', 'hospital_billing', 'hospital_admin')
ORDER BY RoleName, ObjectName;
GO