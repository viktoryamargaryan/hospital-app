-- ============================================================
--  TRIGGERS
-- ============================================================
USE HospitalDB;
GO

IF OBJECT_ID('trg_CapitalizePatientName', 'TR') IS NOT NULL DROP TRIGGER trg_CapitalizePatientName;
IF OBJECT_ID('trg_PreventDoctorDelete', 'TR') IS NOT NULL DROP TRIGGER trg_PreventDoctorDelete;
IF OBJECT_ID('trg_AutoBillDate', 'TR') IS NOT NULL DROP TRIGGER trg_AutoBillDate;
IF OBJECT_ID('trg_PreventDoubleBooking', 'TR') IS NOT NULL DROP TRIGGER trg_PreventDoubleBooking;
IF OBJECT_ID('trg_LogRoomStatusChange', 'TR') IS NOT NULL DROP TRIGGER trg_LogRoomStatusChange;
IF OBJECT_ID('trg_ValidateBillingAmount', 'TR') IS NOT NULL DROP TRIGGER trg_ValidateBillingAmount;
GO

-- 1. Trigger: trg_PreventDoubleBooking
--Business Rule: A doctor cannot be booked for two different appointments at the exact same date and time. 
--This ensures schedule integrity.

CREATE TRIGGER trg_PreventDoubleBooking
ON APPOINTMENT
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Check if the doctor is already busy at that specific slot
    IF EXISTS (
        SELECT 1
        FROM APPOINTMENT A
        JOIN inserted i ON A.DoctorID = i.DoctorID
                       AND A.Date     = i.Date
                       AND A.Time     = i.Time
    )
    BEGIN
        RAISERROR('Cannot book: Doctor already has an appointment at this date and time.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    -- If slot is free, proceed with the insertion
    INSERT INTO APPOINTMENT(AppointID, Date, Time, Status, PatientID, DoctorID)
    SELECT AppointID, Date, Time, Status, PatientID, DoctorID FROM inserted;
END;
GO

-- 2. Trigger: trg_LogRoomStatusChange
-- Business Rule: Every time a room's status changes (e.g., from 'Vacant' to 'Occupied'), 
-- it must be logged in the ROOM_AUDIT table for tracking purposes.

CREATE TRIGGER trg_LogRoomStatusChange
ON ROOM
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Insert record into audit table only if the Status column actually changed
    INSERT INTO ROOM_AUDIT(RoomID, OldStatus, NewStatus, ChangedAt)
    SELECT d.RoomID, d.Status, i.Status, GETDATE()
    FROM deleted d
    JOIN inserted i ON d.RoomID = i.RoomID
    WHERE d.Status <> i.Status;
END;
GO

-- 3. Trigger: trg_AutoBillDate
-- Business Rule: To reduce manual data entry, if a bill is created without a date,
-- the trigger automatically pulls the date from the associated appointment.

CREATE TRIGGER trg_AutoBillDate
ON BILLING
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Sync the BillDate with the Appointment date if it was left NULL
    UPDATE BILLING
    SET BillDate = (SELECT Date FROM APPOINTMENT WHERE AppointID = i.AppointID)
    FROM BILLING
    JOIN inserted i ON BILLING.BillID = i.BillID
    WHERE i.BillDate IS NULL;
END;
GO

-- 4. Trigger: trg_PreventDoctorDelete
-- Business Rule: A doctor cannot be deleted from the system if they still have active appointments assigned to them. 
-- This protects referential integrity.

CREATE TRIGGER trg_PreventDoctorDelete
ON DOCTOR
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- Block deletion if appointments exist for this doctor
    IF EXISTS (
        SELECT 1 FROM APPOINTMENT A
        JOIN deleted D ON A.DoctorID = D.DoctorID
    )
    BEGIN
        RAISERROR('Cannot delete doctor: active appointments exist.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    DELETE FROM DOCTOR WHERE DoctorID IN (SELECT DoctorID FROM deleted);
END;
GO

-- 5. Trigger: trg_ValidateBillingAmount
-- Business Rule: Prevents accidental data entry of zero or negative billing amounts.

CREATE TRIGGER trg_ValidateBillingAmount
ON BILLING
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Enforce that billing must always be a positive number
    IF EXISTS (SELECT 1 FROM inserted WHERE TotalAmount <= 0)
    BEGIN
        RAISERROR('Billing error: TotalAmount must be greater than zero.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    INSERT INTO BILLING(BillID, PatientID, AppointID, TotalAmount, PaymentStatus, BillDate)
    SELECT BillID, PatientID, AppointID, TotalAmount, PaymentStatus, BillDate FROM inserted;
END;
GO

-- 6. Trigger: trg_CapitalizePatientName
-- Business Rule: Automatically ensures all patient first names are properly capitalized (First letter upper, rest lower) 
-- regardless of how they were typed.

CREATE TRIGGER trg_CapitalizePatientName
ON PATIENT
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Formatting logic for consistent naming
    UPDATE PATIENT
    SET FirstName = UPPER(SUBSTRING(i.FirstName, 1, 1))
                  + LOWER(SUBSTRING(i.FirstName, 2, LEN(i.FirstName) - 1))
    FROM PATIENT
    JOIN inserted i ON PATIENT.PatientID = i.PatientID;
END;
GO

-- 7. Verification Query
-- Run this to confirm all your new triggers are active and correctly assigned to their respective tables:

SELECT 
    t.name AS TableName, 
    tr.name AS TriggerName, 
    tr.type_desc AS ExecutionType,
    CASE WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS TriggerTiming
FROM sys.triggers tr
INNER JOIN sys.tables t ON tr.parent_id = t.object_id
ORDER BY TableName;
GO