-- ============================================================
-- DROP STATEMENTS FOR HOSPITAL SYSTEM STORED PROCEDURES
-- ============================================================
USE HospitalDB;
GO
IF OBJECT_ID('dbo.usp_RegisterPatient', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_RegisterPatient;
GO
IF OBJECT_ID('dbo.usp_BookAppointment', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_BookAppointment;
GO
IF OBJECT_ID('dbo.usp_GetPatientFullHistory', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetPatientFullHistory;
GO
IF OBJECT_ID('dbo.usp_IssuePrescription', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_IssuePrescription;
GO
IF OBJECT_ID('dbo.usp_UpdateRoomStatus', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_UpdateRoomStatus;
GO
IF OBJECT_ID('dbo.usp_GenerateBill', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GenerateBill;
GO
IF OBJECT_ID('dbo.usp_ProcessPayment', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_ProcessPayment;
GO
IF OBJECT_ID('dbo.usp_GetDoctorSchedule', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetDoctorSchedule;
GO
IF OBJECT_ID('dbo.usp_DepartmentRevenueReport', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_DepartmentRevenueReport;
GO
IF OBJECT_ID('dbo.usp_DischargePatient', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_DischargePatient;
GO

--1. usp_RegisterPatient
--Purpose: Registers a new patient and their emergency contact in a single transaction to ensure data integrity.
--Tables: PATIENT, EMERGENCY_CONTACT

CREATE PROCEDURE usp_RegisterPatient
    @PatientID INT,
    @FirstName VARCHAR(50),
    @LastName  VARCHAR(50),
    @DOB       DATE,
    @Phone     VARCHAR(20),
    @Address   VARCHAR(255),
    @ECName    VARCHAR(100),
    @ECPhone   VARCHAR(20),
    @ECRelation VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO PATIENT (PatientID, FirstName, LastName, DOB, Phone, Address)
        VALUES (@PatientID, @FirstName, @LastName, @DOB, @Phone, @Address);

        -- Uses a generated ID for ContactID based on existing max
        DECLARE @NewECID INT = (SELECT ISNULL(MAX(ContactID), 0) + 1 FROM EMERGENCY_CONTACT);

        INSERT INTO EMERGENCY_CONTACT (ContactID, PatientID, ContactName, Phone, Relationship)
        VALUES (@NewECID, @PatientID, @ECName, @ECPhone, @ECRelation);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

--2. usp_BookAppointment
--Purpose: Books an appointment while checking for doctor availability to prevent double-booking.
--Tables: APPOINTMENT

CREATE PROCEDURE usp_BookAppointment
    @PatientID INT,
    @DoctorID  INT,
    @Date      DATE,
    @Time      TIME
AS
BEGIN
    SET NOCOUNT ON;
    -- Check if doctor is already busy
    IF EXISTS (SELECT 1 FROM APPOINTMENT WHERE DoctorID = @DoctorID AND Date = @Date AND Time = @Time)
    BEGIN
        RAISERROR('The doctor is already booked for this specific time slot.', 16, 1);
        RETURN;
    END

    DECLARE @NewID INT = (SELECT ISNULL(MAX(AppointID), 0) + 1 FROM APPOINTMENT);

    INSERT INTO APPOINTMENT (AppointID, Date, Time, Status, PatientID, DoctorID)
    VALUES (@NewID, @Date, @Time, 'Scheduled', @PatientID, @DoctorID);
END;
GO
--3. usp_GetPatientFullHistory
--Purpose: Retrieves a comprehensive view of a patient, including their personal info, medical history, and insurance.
--Tables: PATIENT, MEDICAL_HISTORY, INSURANCE

CREATE PROCEDURE usp_GetPatientFullHistory
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        P.FirstName, P.LastName, P.DOB,
        MH.Diagnosis, MH.SurgeryHistory, MH.Allergies,
        I.ProviderName, I.PolicyNumber
    FROM PATIENT P
    LEFT JOIN MEDICAL_HISTORY MH ON P.PatientID = MH.PatientID
    LEFT JOIN INSURANCE I ON P.PatientID = I.PatientID
    WHERE P.PatientID = @PatientID;
END;
GO

--4. usp_IssuePrescription
--Purpose: Creates a prescription record and links multiple medicines to it.
--Tables: PRESCRIPTION, PRESCRIPTION_CONTAINS

CREATE PROCEDURE usp_IssuePrescription
    @AppointID INT,
    @MedicineID INT,
    @Dosage VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PresID INT = (SELECT ISNULL(MAX(PrescriptionID), 0) + 1 FROM PRESCRIPTION);

        INSERT INTO PRESCRIPTION (PrescriptionID, DateIssued, AppointID)
        VALUES (@PresID, CAST(GETDATE() AS DATE), @AppointID);

        INSERT INTO PRESCRIPTION_CONTAINS (PrescriptionID, MedicineID, Dosage)
        VALUES (@PresID, @MedicineID, @Dosage);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

--5. usp_UpdateRoomStatus
--Purpose: Updates a room's status (e.g., from Vacant to Occupied). This will also trigger your trg_LogRoomStatusChange to audit the move.
--Tables: ROOM

CREATE PROCEDURE usp_UpdateRoomStatus
    @RoomID INT,
    @NewStatus VARCHAR(20)
AS
BEGIN
    UPDATE ROOM 
    SET Status = @NewStatus 
    WHERE RoomID = @RoomID;
END;
GO

--6. usp_GenerateBill
--Purpose: Automatically generates a bill for an appointment.
--Tables: BILLING


CREATE PROCEDURE usp_GenerateBill
    @PatientID INT,
    @AppointID INT,
    @Amount DECIMAL(10,2)
AS
BEGIN
    DECLARE @BillID INT = (SELECT ISNULL(MAX(BillID), 0) + 1 FROM BILLING);
    
    INSERT INTO BILLING (BillID, PatientID, AppointID, TotalAmount, PaymentStatus, BillDate)
    VALUES (@BillID, @PatientID, @AppointID, @Amount, 'Pending', GETDATE());
END;
GO

--7. usp_ProcessPayment
--Purpose: Marks a pending bill as 'Paid'.
--Tables: BILLING


CREATE PROCEDURE usp_ProcessPayment
    @BillID INT
AS
BEGIN
    UPDATE BILLING 
    SET PaymentStatus = 'Paid' 
    WHERE BillID = @BillID AND PaymentStatus = 'Pending';
END;
GO


--8. usp_GetDoctorSchedule
--Purpose: Lists all appointments for a specific doctor on a given date.
--Tables: APPOINTMENT, PATIENT

CREATE PROCEDURE usp_GetDoctorSchedule
    @DoctorID INT,
    @WorkDate DATE
AS
BEGIN
    SELECT A.Time, P.FirstName, P.LastName, A.Status
    FROM APPOINTMENT A
    JOIN PATIENT P ON A.PatientID = P.PatientID
    WHERE A.DoctorID = @DoctorID AND A.Date = @WorkDate
    ORDER BY A.Time;
END;
GO

--9. usp_DepartmentRevenueReport
--Purpose: Provides a financial overview of how much revenue each department is generating.
--Tables: DEPARTMENT, DOCTOR, APPOINTMENT, BILLING


CREATE PROCEDURE usp_DepartmentRevenueReport
AS
BEGIN
    SELECT 
        DeptName, 
        SUM(TotalAmount) AS TotalRevenue,
        COUNT(BillID) AS BillCount
    FROM DEPARTMENT DE
    JOIN DOCTOR D ON DE.DeptID = D.DeptID
    JOIN APPOINTMENT A ON D.DoctorID = A.DoctorID
    JOIN BILLING B ON A.AppointID = B.AppointID
    WHERE B.PaymentStatus = 'Paid'
    GROUP BY DeptName;
END;
GO

--10. usp_DischargePatient
--Purpose: A cleanup procedure to mark appointments as completed and free up the room.
--Tables: APPOINTMENT, ROOM


CREATE PROCEDURE usp_DischargePatient
    @PatientID INT,
    @RoomID INT
AS
BEGIN
    BEGIN TRANSACTION;
    -- Update appointment status
    UPDATE APPOINTMENT SET Status = 'Completed' 
    WHERE PatientID = @PatientID AND Status = 'Scheduled';

    -- Free the room
    UPDATE ROOM SET Status = 'Vacant' WHERE RoomID = @RoomID;
    
    COMMIT TRANSACTION;
END;
GO

--Verification
--To verify they are created, run:


SELECT name, create_date FROM sys.procedures WHERE name LIKE 'usp_%';