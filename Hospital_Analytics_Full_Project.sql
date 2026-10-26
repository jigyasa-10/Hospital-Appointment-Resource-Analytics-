/* =====================================================================
   HOSPITAL APPOINTMENT & RESOURCE ANALYTICS - FULL PROJECT (single file)
   Platform : Microsoft SQL Server (SSMS), 2016 SP1 or later
   HOW TO RUN: open this file in SSMS and press F5 once. This builds everything (Parts 1-3).
   Part 4 (analytics) will also run and show many result tabs; or highlight a single query and press F5.
   Part 1 = schema | Part 2 = data | Part 3 = views/procedures | Part 4 = analytics
   ===================================================================== */

/* =====================================================================
   Hospital Appointment & Resource Analytics
   Script 01 : Create database, tables, constraints and indexes
   Platform  : Microsoft SQL Server (SSMS), 2016 or later
   ===================================================================== */

USE master;
GO

IF DB_ID('HospitalAnalytics') IS NOT NULL
BEGIN
    ALTER DATABASE HospitalAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HospitalAnalytics;
END
GO

CREATE DATABASE HospitalAnalytics;
GO

USE HospitalAnalytics;
GO

/* ---------------------------- Departments ---------------------------- */
CREATE TABLE Departments (
    DepartmentID    INT IDENTITY(1,1) CONSTRAINT PK_Departments PRIMARY KEY,
    DepartmentName  VARCHAR(60)  NOT NULL CONSTRAINT UQ_Departments_Name UNIQUE,
    Location        VARCHAR(60)  NOT NULL,
    BedCapacity     INT          NOT NULL CONSTRAINT CK_Departments_Beds CHECK (BedCapacity >= 0)
);
GO

/* ------------------------------ Doctors ------------------------------ */
CREATE TABLE Doctors (
    DoctorID        INT IDENTITY(1,1) CONSTRAINT PK_Doctors PRIMARY KEY,
    FirstName       VARCHAR(50)  NOT NULL,
    LastName        VARCHAR(50)  NOT NULL,
    Specialization  VARCHAR(80)  NOT NULL,
    DepartmentID    INT          NOT NULL
        CONSTRAINT FK_Doctors_Departments REFERENCES Departments(DepartmentID),
    Phone           VARCHAR(15)  NULL,
    Email           VARCHAR(100) NOT NULL CONSTRAINT UQ_Doctors_Email UNIQUE,
    ConsultationFee DECIMAL(10,2) NOT NULL CONSTRAINT CK_Doctors_Fee CHECK (ConsultationFee >= 0),
    HireDate        DATE         NOT NULL
);
GO

/* ------------------------------ Patients ----------------------------- */
CREATE TABLE Patients (
    PatientID        INT IDENTITY(1,1) CONSTRAINT PK_Patients PRIMARY KEY,
    FirstName        VARCHAR(50) NOT NULL,
    LastName         VARCHAR(50) NOT NULL,
    Gender           CHAR(1)     NOT NULL CONSTRAINT CK_Patients_Gender CHECK (Gender IN ('M','F','O')),
    DateOfBirth      DATE        NOT NULL,
    Phone            VARCHAR(15) NULL,
    City             VARCHAR(50) NULL,
    RegistrationDate DATE        NOT NULL
);
GO

/* ---------------------------- Appointments --------------------------- */
CREATE TABLE Appointments (
    AppointmentID      INT IDENTITY(1,1) CONSTRAINT PK_Appointments PRIMARY KEY,
    PatientID          INT  NOT NULL
        CONSTRAINT FK_Appointments_Patients REFERENCES Patients(PatientID),
    DoctorID           INT  NOT NULL
        CONSTRAINT FK_Appointments_Doctors REFERENCES Doctors(DoctorID),
    AppointmentDate    DATE NOT NULL,
    AppointmentTime    TIME(0) NOT NULL,
    Status             VARCHAR(15) NOT NULL
        CONSTRAINT CK_Appointments_Status CHECK (Status IN ('Scheduled','Completed','Cancelled','No-Show')),
    VisitReason        VARCHAR(100) NULL,
    CancellationReason VARCHAR(100) NULL
);
GO

/* -------------------------------- Bills ------------------------------ */
CREATE TABLE Bills (
    BillID             INT IDENTITY(1,1) CONSTRAINT PK_Bills PRIMARY KEY,
    AppointmentID      INT NOT NULL
        CONSTRAINT FK_Bills_Appointments REFERENCES Appointments(AppointmentID)
        CONSTRAINT UQ_Bills_Appointment UNIQUE,
    BillDate           DATE NOT NULL,
    ConsultationCharge DECIMAL(10,2) NOT NULL DEFAULT 0,
    MedicineCharge     DECIMAL(10,2) NOT NULL DEFAULT 0,
    LabCharge          DECIMAL(10,2) NOT NULL DEFAULT 0,
    TotalAmount        AS (ConsultationCharge + MedicineCharge + LabCharge) PERSISTED,
    AmountPaid         DECIMAL(10,2) NOT NULL DEFAULT 0,
    PaymentStatus      VARCHAR(10) NOT NULL
        CONSTRAINT CK_Bills_PayStatus CHECK (PaymentStatus IN ('Paid','Partial','Pending')),
    PaymentMethod      VARCHAR(15) NULL
        CONSTRAINT CK_Bills_PayMethod CHECK (PaymentMethod IN ('Cash','Card','UPI','Insurance')),
    CONSTRAINT CK_Bills_PaidLimit CHECK (AmountPaid <= ConsultationCharge + MedicineCharge + LabCharge)
);
GO

/* ------------------------------ Indexes ------------------------------ */
CREATE INDEX IX_Appointments_Date    ON Appointments(AppointmentDate) INCLUDE (Status);
CREATE INDEX IX_Appointments_Doctor  ON Appointments(DoctorID, AppointmentDate);
CREATE INDEX IX_Appointments_Patient ON Appointments(PatientID);
CREATE INDEX IX_Appointments_Status  ON Appointments(Status);
CREATE INDEX IX_Doctors_Department   ON Doctors(DepartmentID);
CREATE INDEX IX_Bills_Date           ON Bills(BillDate);
CREATE INDEX IX_Bills_PayStatus      ON Bills(PaymentStatus);
GO

PRINT 'Schema created successfully.';
GO


/* =====================================================================
   Hospital Appointment & Resource Analytics
   Script 02 : Synthetic data (8 departments, 24 doctors, 300 patients,
               2000 appointments, bills for completed visits)
   Run AFTER 01_create_schema.sql
   Dates are relative to today, so the data always looks current.
   ===================================================================== */

USE HospitalAnalytics;
GO
SET NOCOUNT ON;
GO

/* ---------------------------- Departments ---------------------------- */
INSERT INTO Departments (DepartmentName, Location, BedCapacity) VALUES
('Cardiology',       'Block A - Floor 2', 40),
('Neurology',        'Block A - Floor 3', 30),
('Orthopedics',      'Block B - Floor 1', 45),
('Pediatrics',       'Block B - Floor 2', 50),
('Dermatology',      'Block C - Floor 1', 10),
('General Medicine', 'Block C - Floor 2', 60),
('Gynecology',       'Block D - Floor 1', 35),
('ENT',              'Block D - Floor 2', 15);
GO

/* ------------------------------ Doctors ------------------------------ */
INSERT INTO Doctors (FirstName, LastName, Specialization, DepartmentID, Phone, Email, ConsultationFee, HireDate) VALUES
('Rajesh',  'Sharma',  'Interventional Cardiology', 1, '9810000001', 'rajesh.sharma@hospital.test',  1500, '2012-04-10'),
('Meera',   'Kapoor',  'Cardiac Electrophysiology', 1, '9810000002', 'meera.kapoor@hospital.test',   1400, '2015-08-21'),
('Anil',    'Verma',   'General Cardiology',        1, '9810000003', 'anil.verma@hospital.test',     1200, '2018-01-15'),
('Sunita',  'Rao',     'Neurology',                 2, '9810000004', 'sunita.rao@hospital.test',     1300, '2013-06-30'),
('Vikram',  'Singh',   'Neurosurgery',              2, '9810000005', 'vikram.singh@hospital.test',   1800, '2010-02-14'),
('Pooja',   'Nair',    'Stroke Medicine',           2, '9810000006', 'pooja.nair@hospital.test',     1250, '2019-09-01'),
('Harpreet','Gill',    'Joint Replacement',         3, '9810000007', 'harpreet.gill@hospital.test',  1400, '2011-11-11'),
('Amit',    'Joshi',   'Sports Medicine',           3, '9810000008', 'amit.joshi@hospital.test',     1100, '2017-03-05'),
('Neha',    'Bansal',  'Spine Surgery',             3, '9810000009', 'neha.bansal@hospital.test',    1600, '2014-07-19'),
('Kavita',  'Menon',   'Pediatric Medicine',        4, '9810000010', 'kavita.menon@hospital.test',    800, '2012-12-01'),
('Sandeep', 'Malhotra','Neonatology',               4, '9810000011', 'sandeep.malhotra@hospital.test',900, '2016-05-23'),
('Ritu',    'Arora',   'Pediatric Allergy',         4, '9810000012', 'ritu.arora@hospital.test',      850, '2020-02-10'),
('Manish',  'Gupta',   'Dermatology',               5, '9810000013', 'manish.gupta@hospital.test',    900, '2014-10-10'),
('Divya',   'Chopra',  'Cosmetic Dermatology',      5, '9810000014', 'divya.chopra@hospital.test',   1000, '2018-04-18'),
('Karan',   'Sethi',   'Pediatric Dermatology',     5, '9810000015', 'karan.sethi@hospital.test',     950, '2021-01-25'),
('Suresh',  'Reddy',   'Internal Medicine',         6, '9810000016', 'suresh.reddy@hospital.test',    700, '2009-09-09'),
('Anjali',  'Mehta',   'Diabetology',               6, '9810000017', 'anjali.mehta@hospital.test',    750, '2013-03-17'),
('Gurpreet','Dhillon', 'Family Medicine',           6, '9810000018', 'gurpreet.dhillon@hospital.test',650, '2019-06-12'),
('Shalini', 'Iyer',    'Obstetrics',                7, '9810000019', 'shalini.iyer@hospital.test',   1100, '2011-08-08'),
('Priya',   'Khanna',  'Gynecologic Oncology',      7, '9810000020', 'priya.khanna@hospital.test',   1500, '2015-01-20'),
('Rekha',   'Saxena',  'Reproductive Medicine',     7, '9810000021', 'rekha.saxena@hospital.test',   1300, '2017-10-02'),
('Arjun',   'Bhatia',  'Otolaryngology',            8, '9810000022', 'arjun.bhatia@hospital.test',    800, '2016-04-04'),
('Tanvi',   'Desai',   'Head and Neck Surgery',     8, '9810000023', 'tanvi.desai@hospital.test',    1200, '2014-12-12'),
('Rohit',   'Pillai',  'Audiology and ENT',         8, '9810000024', 'rohit.pillai@hospital.test',    750, '2020-07-07');
GO

/* ------------------------------ Patients ----------------------------- */
IF OBJECT_ID('tempdb..#P') IS NOT NULL DROP TABLE #P;

SELECT TOP (300)
       n      = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
       g      = ABS(CHECKSUM(NEWID())) % 2,         -- 0 = male, 1 = female
       fn     = ABS(CHECKSUM(NEWID())) % 10 + 1,
       ln     = ABS(CHECKSUM(NEWID())) % 20 + 1,
       ageDay = ABS(CHECKSUM(NEWID())) % (365 * 85) + 30,
       city   = ABS(CHECKSUM(NEWID())) % 8 + 1,
       regDay = ABS(CHECKSUM(NEWID())) % 1000,
       ph     = ABS(CHECKSUM(NEWID())) % 1000000000
INTO #P
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

INSERT INTO Patients (FirstName, LastName, Gender, DateOfBirth, Phone, City, RegistrationDate)
SELECT
    CASE WHEN g = 0
         THEN CHOOSE(fn, 'Aarav','Rohan','Vivaan','Arnav','Kabir','Ishaan','Dev','Yash','Harsh','Manav')
         ELSE CHOOSE(fn, 'Aanya','Diya','Isha','Kiara','Myra','Riya','Saanvi','Tara','Zoya','Naina')
    END,
    CHOOSE(ln, 'Sharma','Verma','Gupta','Singh','Kaur','Patel','Mehta','Joshi','Kapoor','Malhotra',
               'Chopra','Bansal','Arora','Bhatia','Sethi','Gill','Dhillon','Khanna','Saxena','Nair'),
    CASE WHEN g = 0 THEN 'M' ELSE 'F' END,
    DATEADD(DAY, -ageDay, CAST(GETDATE() AS DATE)),
    '9' + RIGHT('000000000' + CAST(ph AS VARCHAR(9)), 9),
    CHOOSE(city, 'Amritsar','Chandigarh','Ludhiana','Jalandhar','Delhi','Patiala','Jammu','Bathinda'),
    DATEADD(DAY, -regDay, CAST(GETDATE() AS DATE))
FROM #P
ORDER BY n;

DROP TABLE #P;
GO

/* ---------------------------- Appointments --------------------------- */
-- Range: about 390 days in the past up to about 30 days in the future.
IF OBJECT_ID('tempdb..#A') IS NOT NULL DROP TABLE #A;

SELECT TOP (2000)
       PatientID = ABS(CHECKSUM(NEWID())) % 300 + 1,
       DoctorID  = ABS(CHECKSUM(NEWID())) % 24  + 1,
       dayOff    = ABS(CHECKSUM(NEWID())) % 420,
       slot      = ABS(CHECKSUM(NEWID())) % 16,       -- 09:00 to 16:30, 30-min slots
       r         = ABS(CHECKSUM(NEWID())) % 100,
       cr        = ABS(CHECKSUM(NEWID())) % 5  + 1,
       vr        = ABS(CHECKSUM(NEWID())) % 8  + 1
INTO #A
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

;WITH X AS (
    SELECT PatientID, DoctorID, slot, r, cr, vr,
           ApptDate = DATEADD(DAY, dayOff - 390, CAST(GETDATE() AS DATE))
    FROM #A
),
Y AS (
    SELECT *,
           Status = CASE
                WHEN ApptDate >= CAST(GETDATE() AS DATE) THEN CASE WHEN r < 93 THEN 'Scheduled' ELSE 'Cancelled' END
                WHEN r < 75 THEN 'Completed'
                WHEN r < 90 THEN 'Cancelled'
                ELSE 'No-Show'
           END
    FROM X
)
INSERT INTO Appointments (PatientID, DoctorID, AppointmentDate, AppointmentTime, Status, VisitReason, CancellationReason)
SELECT PatientID, DoctorID, ApptDate,
       DATEADD(MINUTE, slot * 30, CAST('09:00' AS TIME(0))),
       Status,
       CHOOSE(vr, 'Routine Checkup','Follow-up Visit','Fever','Chest Pain','Skin Allergy',
                  'Joint Pain','Headache','General Consultation'),
       CASE WHEN Status = 'Cancelled'
            THEN CHOOSE(cr, 'Patient request','Doctor unavailable','Emergency','Rescheduled','Travel issue')
       END
FROM Y
ORDER BY ApptDate, slot;

DROP TABLE #A;
GO

/* -------------------------------- Bills ------------------------------ */
-- One bill for every completed appointment.
IF OBJECT_ID('tempdb..#B') IS NOT NULL DROP TABLE #B;

SELECT a.AppointmentID,
       a.AppointmentDate,
       d.ConsultationFee,
       med = (ABS(CHECKSUM(NEWID())) % 21) * 100,     -- 0 to 2000
       lf  = ABS(CHECKSUM(NEWID())) % 100,
       la  = (ABS(CHECKSUM(NEWID())) % 30 + 1) * 100, -- 100 to 3000
       p   = ABS(CHECKSUM(NEWID())) % 100,
       m   = ABS(CHECKSUM(NEWID())) % 4 + 1
INTO #B
FROM Appointments a
JOIN Doctors d ON d.DoctorID = a.DoctorID
WHERE a.Status = 'Completed';

INSERT INTO Bills (AppointmentID, BillDate, ConsultationCharge, MedicineCharge, LabCharge,
                   AmountPaid, PaymentStatus, PaymentMethod)
SELECT b.AppointmentID, b.AppointmentDate, b.ConsultationFee, b.med, x.lab,
       CASE x.status WHEN 'Paid'    THEN t.total
                     WHEN 'Partial' THEN ROUND(t.total * 0.5, 0)
                     ELSE 0 END,
       x.status,
       CASE WHEN x.status = 'Pending' THEN NULL
            ELSE CHOOSE(b.m, 'Cash', 'Card', 'UPI', 'Insurance') END
FROM #B b
CROSS APPLY (SELECT lab    = CASE WHEN b.lf < 60 THEN 0 ELSE b.la END,
                    status = CASE WHEN b.p < 70 THEN 'Paid'
                                  WHEN b.p < 85 THEN 'Partial'
                                  ELSE 'Pending' END) x
CROSS APPLY (SELECT total  = b.ConsultationFee + b.med + x.lab) t
ORDER BY b.AppointmentID;

DROP TABLE #B;
GO

/* ------------------------------ Check -------------------------------- */
SELECT 'Departments'  AS TableName, COUNT(*) AS Total FROM Departments  UNION ALL
SELECT 'Doctors',      COUNT(*) FROM Doctors      UNION ALL
SELECT 'Patients',     COUNT(*) FROM Patients     UNION ALL
SELECT 'Appointments', COUNT(*) FROM Appointments UNION ALL
SELECT 'Bills',        COUNT(*) FROM Bills;
GO


/* =====================================================================
   Hospital Appointment & Resource Analytics
   Script 04 : Reusable views and stored procedures
   Run AFTER 01 and 02. Requires SQL Server 2016 SP1+ (CREATE OR ALTER).
   ===================================================================== */

USE HospitalAnalytics;
GO

/* ------------------------------- Views ------------------------------- */

-- One flat row per appointment, joined across all five tables
CREATE OR ALTER VIEW vw_AppointmentDetails AS
SELECT a.AppointmentID,
       a.AppointmentDate,
       a.AppointmentTime,
       a.Status,
       a.VisitReason,
       a.CancellationReason,
       p.PatientID,
       p.FirstName + ' ' + p.LastName            AS PatientName,
       p.Gender,
       DATEDIFF(YEAR, p.DateOfBirth, GETDATE())  AS PatientAge,
       p.City,
       d.DoctorID,
       'Dr. ' + d.FirstName + ' ' + d.LastName   AS DoctorName,
       d.Specialization,
       dep.DepartmentID,
       dep.DepartmentName,
       b.BillID,
       b.TotalAmount,
       b.AmountPaid,
       b.TotalAmount - b.AmountPaid              AS AmountDue,
       b.PaymentStatus,
       b.PaymentMethod
FROM Appointments a
JOIN Patients p      ON p.PatientID = a.PatientID
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
LEFT JOIN Bills b    ON b.AppointmentID = a.AppointmentID;
GO

-- Department-level KPI summary
CREATE OR ALTER VIEW vw_DepartmentSummary AS
SELECT DepartmentName,
       COUNT(*)                                                     AS TotalAppointments,
       SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END)        AS Completed,
       SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)        AS Cancelled,
       SUM(CASE WHEN Status = 'No-Show'   THEN 1 ELSE 0 END)        AS NoShow,
       SUM(CASE WHEN Status = 'Scheduled' THEN 1 ELSE 0 END)        AS Upcoming,
       ISNULL(SUM(TotalAmount), 0)                                  AS TotalBilled,
       ISNULL(SUM(AmountPaid), 0)                                   AS Collected
FROM vw_AppointmentDetails
GROUP BY DepartmentName;
GO

-- Monthly KPI summary
CREATE OR ALTER VIEW vw_MonthlySummary AS
SELECT DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1) AS MonthStart,
       COUNT(*)                                                 AS TotalAppointments,
       SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END)    AS Completed,
       SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)    AS Cancelled,
       SUM(CASE WHEN Status = 'No-Show'   THEN 1 ELSE 0 END)    AS NoShow,
       ISNULL(SUM(TotalAmount), 0)                              AS TotalBilled,
       ISNULL(SUM(AmountPaid), 0)                               AS Collected
FROM vw_AppointmentDetails
GROUP BY DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1);
GO

/* ------------------------- Stored procedures ------------------------- */

-- Department report for a date range (defaults to the last 90 days)
CREATE OR ALTER PROCEDURE usp_DepartmentReport
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @EndDate   = ISNULL(@EndDate,   CAST(GETDATE() AS DATE));
    SET @StartDate = ISNULL(@StartDate, DATEADD(DAY, -90, @EndDate));

    SELECT DepartmentName,
           COUNT(*)                                                 AS TotalAppointments,
           SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END)    AS Completed,
           SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)    AS Cancelled,
           SUM(CASE WHEN Status = 'No-Show'   THEN 1 ELSE 0 END)    AS NoShow,
           CAST(100.0 * SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))              AS CancelRatePct,
           ISNULL(SUM(TotalAmount), 0)                              AS TotalBilled,
           ISNULL(SUM(AmountPaid), 0)                               AS Collected
    FROM vw_AppointmentDetails
    WHERE AppointmentDate BETWEEN @StartDate AND @EndDate
    GROUP BY DepartmentName
    ORDER BY TotalAppointments DESC;
END
GO

-- A doctor's schedule for one day
CREATE OR ALTER PROCEDURE usp_DoctorSchedule
    @DoctorID INT,
    @Date     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Date = ISNULL(@Date, CAST(GETDATE() AS DATE));

    SELECT AppointmentTime, PatientName, PatientAge, VisitReason, Status
    FROM vw_AppointmentDetails
    WHERE DoctorID = @DoctorID
      AND AppointmentDate = @Date
    ORDER BY AppointmentTime;
END
GO

-- Full history for one patient, with billing
CREATE OR ALTER PROCEDURE usp_PatientHistory
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT AppointmentDate, AppointmentTime, DoctorName, DepartmentName,
           Status, VisitReason, TotalAmount, AmountPaid, AmountDue, PaymentStatus
    FROM vw_AppointmentDetails
    WHERE PatientID = @PatientID
    ORDER BY AppointmentDate DESC, AppointmentTime DESC;
END
GO

-- Book a new appointment with a double-booking check
CREATE OR ALTER PROCEDURE usp_BookAppointment
    @PatientID   INT,
    @DoctorID    INT,
    @ApptDate    DATE,
    @ApptTime    TIME(0),
    @VisitReason VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ApptDate < CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR('Cannot book an appointment in the past.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Appointments
               WHERE DoctorID = @DoctorID
                 AND AppointmentDate = @ApptDate
                 AND AppointmentTime = @ApptTime
                 AND Status IN ('Scheduled', 'Completed'))
    BEGIN
        RAISERROR('This doctor is already booked for the selected slot.', 16, 1);
        RETURN;
    END

    INSERT INTO Appointments (PatientID, DoctorID, AppointmentDate, AppointmentTime, Status, VisitReason)
    VALUES (@PatientID, @DoctorID, @ApptDate, @ApptTime, 'Scheduled', @VisitReason);

    SELECT SCOPE_IDENTITY() AS NewAppointmentID;
END
GO

-- Cancel an upcoming appointment
CREATE OR ALTER PROCEDURE usp_CancelAppointment
    @AppointmentID INT,
    @Reason        VARCHAR(100) = 'Patient request'
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Appointments
    SET Status = 'Cancelled', CancellationReason = @Reason
    WHERE AppointmentID = @AppointmentID
      AND Status = 'Scheduled';

    IF @@ROWCOUNT = 0
        RAISERROR('Appointment not found or not in Scheduled status.', 16, 1);
END
GO

/* ------------------------------ Examples ------------------------------ */
-- SELECT * FROM vw_DepartmentSummary ORDER BY TotalAppointments DESC;
-- SELECT * FROM vw_MonthlySummary ORDER BY MonthStart;
-- EXEC usp_DepartmentReport;
-- EXEC usp_DepartmentReport @StartDate = '2026-01-01', @EndDate = '2026-03-31';
-- EXEC usp_DoctorSchedule @DoctorID = 1;
-- EXEC usp_PatientHistory @PatientID = 5;
-- EXEC usp_BookAppointment @PatientID = 5, @DoctorID = 3, @ApptDate = '2026-12-01', @ApptTime = '10:30', @VisitReason = 'Follow-up Visit';


/* =====================================================================
   Hospital Appointment & Resource Analytics
   Script 03 : Analytics queries
   Concepts  : multi-table joins, GROUP BY, date functions, subqueries,
               CTEs and window functions
   Run AFTER 01 and 02. Highlight one query at a time and press F5.
   ===================================================================== */

USE HospitalAnalytics;
GO

/* =====================================================================
   SECTION A : APPOINTMENT TRENDS
   ===================================================================== */

-- A1. Monthly appointment volume with month-over-month change
;WITH Monthly AS (
    SELECT DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1) AS MonthStart,
           COUNT(*) AS TotalAppointments,
           SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END) AS Completed,
           SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
           SUM(CASE WHEN Status = 'No-Show'   THEN 1 ELSE 0 END) AS NoShow
    FROM Appointments
    GROUP BY DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1)
)
SELECT MonthStart,
       TotalAppointments, Completed, Cancelled, NoShow,
       LAG(TotalAppointments) OVER (ORDER BY MonthStart) AS PrevMonth,
       CAST(100.0 * (TotalAppointments - LAG(TotalAppointments) OVER (ORDER BY MonthStart))
            / NULLIF(LAG(TotalAppointments) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,2)) AS MoM_ChangePct
FROM Monthly
ORDER BY MonthStart;

-- A2. Busiest days of the week
SELECT DATENAME(WEEKDAY, AppointmentDate) AS DayName,
       COUNT(*) AS TotalAppointments,
       CAST(AVG(1.0 * COUNT(*)) OVER () AS DECIMAL(10,2)) AS AvgPerDayName
FROM Appointments
GROUP BY DATENAME(WEEKDAY, AppointmentDate), DATEPART(WEEKDAY, AppointmentDate)
ORDER BY TotalAppointments DESC;

-- A3. Peak hours of the day
SELECT DATEPART(HOUR, AppointmentTime) AS HourOfDay,
       COUNT(*) AS TotalAppointments
FROM Appointments
GROUP BY DATEPART(HOUR, AppointmentTime)
ORDER BY HourOfDay;

-- A4. Quarterly trend
SELECT YEAR(AppointmentDate) AS Yr,
       DATEPART(QUARTER, AppointmentDate) AS Qtr,
       COUNT(*) AS TotalAppointments
FROM Appointments
GROUP BY YEAR(AppointmentDate), DATEPART(QUARTER, AppointmentDate)
ORDER BY Yr, Qtr;

-- A5. Last 30 days vs the 30 days before that
SELECT SUM(CASE WHEN AppointmentDate >  DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
                 AND AppointmentDate <= CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) AS Last30Days,
       SUM(CASE WHEN AppointmentDate >  DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
                 AND AppointmentDate <= DATEADD(DAY, -30, CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END) AS Previous30Days
FROM Appointments;

-- A6. Upcoming appointments in the next 7 days
SELECT a.AppointmentDate, a.AppointmentTime,
       p.FirstName + ' ' + p.LastName AS Patient,
       'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor,
       dep.DepartmentName
FROM Appointments a
JOIN Patients    p   ON p.PatientID    = a.PatientID
JOIN Doctors     d   ON d.DoctorID     = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
WHERE a.Status = 'Scheduled'
  AND a.AppointmentDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 7, CAST(GETDATE() AS DATE))
ORDER BY a.AppointmentDate, a.AppointmentTime;

/* =====================================================================
   SECTION B : DEPARTMENT WORKLOAD
   ===================================================================== */

-- B1. Workload per department
SELECT dep.DepartmentName,
       COUNT(DISTINCT d.DoctorID)  AS Doctors,
       COUNT(a.AppointmentID)      AS TotalAppointments,
       COUNT(DISTINCT a.PatientID) AS UniquePatients,
       SUM(CASE WHEN a.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed,
       CAST(1.0 * COUNT(a.AppointmentID) / NULLIF(COUNT(DISTINCT d.DoctorID), 0) AS DECIMAL(10,1)) AS ApptsPerDoctor
FROM Departments dep
JOIN Doctors d           ON d.DepartmentID = dep.DepartmentID
LEFT JOIN Appointments a ON a.DoctorID     = d.DoctorID
GROUP BY dep.DepartmentName
ORDER BY TotalAppointments DESC;

-- B2. Doctor ranking inside each department (window function)
;WITH DoctorStats AS (
    SELECT dep.DepartmentName,
           d.DoctorID,
           'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor,
           COUNT(a.AppointmentID) AS Completed
    FROM Doctors d
    JOIN Departments dep     ON dep.DepartmentID = d.DepartmentID
    LEFT JOIN Appointments a ON a.DoctorID = d.DoctorID AND a.Status = 'Completed'
    GROUP BY dep.DepartmentName, d.DoctorID, d.FirstName, d.LastName
)
SELECT DepartmentName, Doctor, Completed,
       RANK() OVER (PARTITION BY DepartmentName ORDER BY Completed DESC) AS RankInDept
FROM DoctorStats
ORDER BY DepartmentName, RankInDept;

-- B3. Department x month workload matrix (pivot)
SELECT DepartmentName,
       [1] AS Jan, [2] AS Feb, [3] AS Mar, [4] AS Apr, [5] AS May, [6] AS Jun,
       [7] AS Jul, [8] AS Aug, [9] AS Sep, [10] AS Oct, [11] AS Nov, [12] AS Dec
FROM (
    SELECT dep.DepartmentName, MONTH(a.AppointmentDate) AS Mth, a.AppointmentID
    FROM Appointments a
    JOIN Doctors d       ON d.DoctorID = a.DoctorID
    JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
) src
PIVOT (COUNT(AppointmentID) FOR Mth IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])) pvt
ORDER BY DepartmentName;

-- B4. Doctor utilisation: appointments per doctor per working day
SELECT 'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor,
       dep.DepartmentName,
       COUNT(*) AS TotalAppointments,
       COUNT(DISTINCT a.AppointmentDate) AS DaysWorked,
       CAST(1.0 * COUNT(*) / COUNT(DISTINCT a.AppointmentDate) AS DECIMAL(6,2)) AS ApptsPerDay
FROM Appointments a
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
WHERE a.Status IN ('Completed', 'No-Show')
GROUP BY d.FirstName, d.LastName, dep.DepartmentName
ORDER BY ApptsPerDay DESC;

/* =====================================================================
   SECTION C : CANCELLATIONS AND NO-SHOWS
   ===================================================================== */

-- C1. Cancellation and no-show rate by department
--     (scheduled future visits are excluded from the denominator)
SELECT dep.DepartmentName,
       COUNT(*) AS ClosedAppointments,
       SUM(CASE WHEN a.Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
       SUM(CASE WHEN a.Status = 'No-Show'   THEN 1 ELSE 0 END) AS NoShow,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS CancelRatePct,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'No-Show'   THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS NoShowRatePct
FROM Appointments a
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
WHERE a.Status <> 'Scheduled'
GROUP BY dep.DepartmentName
ORDER BY CancelRatePct DESC;

-- C2. Cancellation reasons
SELECT CancellationReason,
       COUNT(*) AS Total,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Pct
FROM Appointments
WHERE Status = 'Cancelled'
GROUP BY CancellationReason
ORDER BY Total DESC;

-- C3. Monthly cancellation rate
SELECT DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1) AS MonthStart,
       COUNT(*) AS Appointments,
       SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
       CAST(100.0 * SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS CancelRatePct
FROM Appointments
GROUP BY DATEFROMPARTS(YEAR(AppointmentDate), MONTH(AppointmentDate), 1)
ORDER BY MonthStart;

-- C4. Doctors whose cancellation rate is above the hospital average (subquery)
SELECT 'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor,
       COUNT(*) AS Appointments,
       CAST(100.0 * SUM(CASE WHEN a.Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS CancelRatePct
FROM Appointments a
JOIN Doctors d ON d.DoctorID = a.DoctorID
GROUP BY d.FirstName, d.LastName
HAVING 100.0 * SUM(CASE WHEN a.Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) >
       (SELECT 100.0 * SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) FROM Appointments)
ORDER BY CancelRatePct DESC;

-- C5. Patients with 3 or more cancellations or no-shows
SELECT p.PatientID, p.FirstName + ' ' + p.LastName AS Patient, p.Phone,
       COUNT(*) AS MissedAppointments
FROM Patients p
JOIN Appointments a ON a.PatientID = p.PatientID
WHERE a.Status IN ('Cancelled', 'No-Show')
GROUP BY p.PatientID, p.FirstName, p.LastName, p.Phone
HAVING COUNT(*) >= 3
ORDER BY MissedAppointments DESC;

/* =====================================================================
   SECTION D : BILLING SUMMARIES
   ===================================================================== */

-- D1. Overall billing summary
SELECT COUNT(*)                         AS TotalBills,
       SUM(TotalAmount)                 AS TotalBilled,
       SUM(AmountPaid)                  AS TotalCollected,
       SUM(TotalAmount - AmountPaid)    AS Outstanding,
       CAST(100.0 * SUM(AmountPaid) / SUM(TotalAmount) AS DECIMAL(5,2)) AS CollectionRatePct,
       CAST(AVG(TotalAmount) AS DECIMAL(10,2)) AS AvgBill
FROM Bills;

-- D2. Revenue by department
SELECT dep.DepartmentName,
       COUNT(b.BillID)           AS Bills,
       SUM(b.ConsultationCharge) AS ConsultationRevenue,
       SUM(b.MedicineCharge)     AS MedicineRevenue,
       SUM(b.LabCharge)          AS LabRevenue,
       SUM(b.TotalAmount)        AS TotalBilled,
       SUM(b.AmountPaid)         AS Collected,
       SUM(b.TotalAmount - b.AmountPaid) AS Outstanding
FROM Bills b
JOIN Appointments a  ON a.AppointmentID = b.AppointmentID
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
GROUP BY dep.DepartmentName
ORDER BY TotalBilled DESC;

-- D3. Monthly revenue with running total
;WITH MonthlyRev AS (
    SELECT DATEFROMPARTS(YEAR(BillDate), MONTH(BillDate), 1) AS MonthStart,
           SUM(TotalAmount) AS Billed,
           SUM(AmountPaid)  AS Collected
    FROM Bills
    GROUP BY DATEFROMPARTS(YEAR(BillDate), MONTH(BillDate), 1)
)
SELECT MonthStart, Billed, Collected,
       SUM(Billed) OVER (ORDER BY MonthStart ROWS UNBOUNDED PRECEDING) AS RunningTotalBilled
FROM MonthlyRev
ORDER BY MonthStart;

-- D4. Payment status and payment method breakdown
SELECT PaymentStatus,
       COUNT(*) AS Bills,
       SUM(TotalAmount) AS TotalBilled,
       SUM(AmountPaid)  AS Collected
FROM Bills
GROUP BY PaymentStatus;

SELECT ISNULL(PaymentMethod, 'Not paid yet') AS PaymentMethod,
       COUNT(*) AS Bills,
       SUM(AmountPaid) AS Collected
FROM Bills
GROUP BY PaymentMethod
ORDER BY Collected DESC;

-- D5. Top 10 doctors by revenue generated
SELECT TOP (10)
       'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor,
       dep.DepartmentName,
       COUNT(b.BillID) AS Bills,
       SUM(b.TotalAmount) AS Revenue
FROM Bills b
JOIN Appointments a  ON a.AppointmentID = b.AppointmentID
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
GROUP BY d.FirstName, d.LastName, dep.DepartmentName
ORDER BY Revenue DESC;

-- D6. Outstanding dues older than 30 days (date functions)
SELECT b.BillID, b.BillDate,
       DATEDIFF(DAY, b.BillDate, GETDATE()) AS DaysOverdue,
       p.FirstName + ' ' + p.LastName AS Patient, p.Phone,
       b.TotalAmount - b.AmountPaid AS Due
FROM Bills b
JOIN Appointments a ON a.AppointmentID = b.AppointmentID
JOIN Patients p     ON p.PatientID = a.PatientID
WHERE b.PaymentStatus <> 'Paid'
  AND b.BillDate < DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
ORDER BY Due DESC;

/* =====================================================================
   SECTION E : SUBQUERY EXAMPLES
   ===================================================================== */

-- E1. Doctors handling more appointments than the average doctor
SELECT 'Dr. ' + d.FirstName + ' ' + d.LastName AS Doctor, x.Total
FROM Doctors d
JOIN (SELECT DoctorID, COUNT(*) AS Total FROM Appointments GROUP BY DoctorID) x
     ON x.DoctorID = d.DoctorID
WHERE x.Total > (SELECT AVG(1.0 * t.Total)
                 FROM (SELECT COUNT(*) AS Total FROM Appointments GROUP BY DoctorID) t)
ORDER BY x.Total DESC;

-- E2. Patients whose total spend is above the average patient spend
SELECT p.PatientID, p.FirstName + ' ' + p.LastName AS Patient, SUM(b.TotalAmount) AS TotalSpent
FROM Patients p
JOIN Appointments a ON a.PatientID = p.PatientID
JOIN Bills b        ON b.AppointmentID = a.AppointmentID
GROUP BY p.PatientID, p.FirstName, p.LastName
HAVING SUM(b.TotalAmount) > (SELECT AVG(s.Spent)
                             FROM (SELECT SUM(b2.TotalAmount) AS Spent
                                   FROM Appointments a2
                                   JOIN Bills b2 ON b2.AppointmentID = a2.AppointmentID
                                   GROUP BY a2.PatientID) s)
ORDER BY TotalSpent DESC;

-- E3. Patients registered but never completed a visit (NOT EXISTS)
SELECT p.PatientID, p.FirstName, p.LastName, p.RegistrationDate
FROM Patients p
WHERE NOT EXISTS (SELECT 1 FROM Appointments a
                  WHERE a.PatientID = p.PatientID AND a.Status = 'Completed');

-- E4. Most expensive bill in each department (correlated subquery)
SELECT dep.DepartmentName, b.BillID, b.TotalAmount
FROM Bills b
JOIN Appointments a  ON a.AppointmentID = b.AppointmentID
JOIN Doctors d       ON d.DoctorID = a.DoctorID
JOIN Departments dep ON dep.DepartmentID = d.DepartmentID
WHERE b.TotalAmount = (SELECT MAX(b2.TotalAmount)
                       FROM Bills b2
                       JOIN Appointments a2 ON a2.AppointmentID = b2.AppointmentID
                       JOIN Doctors d2      ON d2.DoctorID = a2.DoctorID
                       WHERE d2.DepartmentID = dep.DepartmentID)
ORDER BY b.TotalAmount DESC;

-- E5. Patients who have an unpaid or partially paid bill (IN subquery)
SELECT PatientID, FirstName, LastName, Phone
FROM Patients
WHERE PatientID IN (SELECT a.PatientID
                    FROM Appointments a
                    JOIN Bills b ON b.AppointmentID = a.AppointmentID
                    WHERE b.PaymentStatus IN ('Pending', 'Partial'));

-- E6. Doctors with no appointments in the last 30 days
SELECT d.DoctorID, d.FirstName, d.LastName
FROM Doctors d
WHERE d.DoctorID NOT IN (SELECT DoctorID FROM Appointments
                         WHERE AppointmentDate >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
                           AND AppointmentDate <= CAST(GETDATE() AS DATE));

/* =====================================================================
   SECTION F : PATIENT DEMOGRAPHICS
   ===================================================================== */

-- F1. Appointments by age group
SELECT CASE WHEN age < 13 THEN '0-12 Child'
            WHEN age < 20 THEN '13-19 Teen'
            WHEN age < 40 THEN '20-39 Adult'
            WHEN age < 60 THEN '40-59 Middle age'
            ELSE '60+ Senior' END AS AgeGroup,
       COUNT(*) AS Appointments
FROM (SELECT DATEDIFF(YEAR, p.DateOfBirth, GETDATE()) AS age
      FROM Appointments a JOIN Patients p ON p.PatientID = a.PatientID) t
GROUP BY CASE WHEN age < 13 THEN '0-12 Child'
              WHEN age < 20 THEN '13-19 Teen'
              WHEN age < 40 THEN '20-39 Adult'
              WHEN age < 60 THEN '40-59 Middle age'
              ELSE '60+ Senior' END
ORDER BY Appointments DESC;

-- F2. Appointments by city and gender
SELECT p.City, p.Gender, COUNT(*) AS Appointments
FROM Appointments a
JOIN Patients p ON p.PatientID = a.PatientID
GROUP BY p.City, p.Gender
ORDER BY p.City, p.Gender;

-- F3. New patient registrations per month
SELECT DATEFROMPARTS(YEAR(RegistrationDate), MONTH(RegistrationDate), 1) AS MonthStart,
       COUNT(*) AS NewPatients
FROM Patients
GROUP BY DATEFROMPARTS(YEAR(RegistrationDate), MONTH(RegistrationDate), 1)
ORDER BY MonthStart;

-- F4. Repeat patients (3 or more completed visits)
SELECT p.PatientID, p.FirstName + ' ' + p.LastName AS Patient,
       COUNT(*) AS CompletedVisits,
       MIN(a.AppointmentDate) AS FirstVisit,
       MAX(a.AppointmentDate) AS LastVisit
FROM Patients p
JOIN Appointments a ON a.PatientID = p.PatientID AND a.Status = 'Completed'
GROUP BY p.PatientID, p.FirstName, p.LastName
HAVING COUNT(*) >= 3
ORDER BY CompletedVisits DESC;
