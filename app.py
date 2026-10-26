"""
CityCare Hospital - Appointment & Resource Analytics
Flask backend that reads from (and writes to) the SQL Server database
`HospitalAnalytics` created by database/Hospital_Analytics_Full_Project.sql.

Run:  python app.py      then open  http://127.0.0.1:5000
"""
import os
import re
from contextlib import contextmanager
from datetime import date, datetime, time
from decimal import Decimal

import pyodbc
from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory

load_dotenv()

app = Flask(__name__, static_folder="static", static_url_path="/static")


# --------------------------------------------------------------------------
# Database connection
# --------------------------------------------------------------------------
def pick_driver():
    """Use DB_DRIVER from .env, otherwise the newest 'ODBC Driver N for SQL Server'."""
    configured = os.getenv("DB_DRIVER", "").strip()
    if configured:
        return configured
    installed = pyodbc.drivers()
    modern = [d for d in installed if d.startswith("ODBC Driver") and "SQL Server" in d]
    if modern:
        return max(modern, key=lambda d: int(re.search(r"\d+", d).group()))
    legacy = [d for d in installed if "SQL Server" in d]
    return legacy[0] if legacy else "ODBC Driver 17 for SQL Server"


def connection_string():
    parts = [
        "DRIVER={%s}" % pick_driver(),
        "SERVER=%s" % os.getenv("DB_SERVER", r"localhost\SQLEXPRESS"),
        "DATABASE=%s" % os.getenv("DB_NAME", "HospitalAnalytics"),
        "TrustServerCertificate=yes",
    ]
    user = os.getenv("DB_USER", "").strip()
    if user:  # SQL Server authentication
        parts += ["UID=%s" % user, "PWD=%s" % os.getenv("DB_PASSWORD", "")]
    else:  # Windows authentication
        parts.append("Trusted_Connection=yes")
    return ";".join(parts)


@contextmanager
def db():
    conn = pyodbc.connect(connection_string(), timeout=5)
    try:
        yield conn
    finally:
        conn.close()


def clean(value):
    """Make SQL Server values JSON friendly."""
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):  # check before date (datetime is a date)
        return value.isoformat(sep=" ", timespec="seconds")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, time):
        return value.strftime("%H:%M")
    return value


def fetch_rows(cursor):
    columns = [c[0] for c in cursor.description]
    return [{c: clean(v) for c, v in zip(columns, row)} for row in cursor.fetchall()]


def query(sql, params=()):
    with db() as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        return fetch_rows(cur)


# --------------------------------------------------------------------------
# Error handling
# --------------------------------------------------------------------------
def sql_message(err):
    text = " ".join(str(a) for a in err.args)
    match = re.search(r"\[SQL Server\](.*?)(?:\s*\(\d+\)|$)", text)
    return (match.group(1).strip() if match else text), text


@app.errorhandler(pyodbc.Error)
def handle_db_error(err):
    message, raw = sql_message(err)
    if "(50000)" in raw:  # RAISERROR raised by our stored procedures
        return jsonify(error=message), 400
    hint = (
        "Could not use the database. Check .env (DB_SERVER, DB_NAME, driver), "
        "that SQL Server is running, and that the SQL script has been executed in SSMS."
    )
    return jsonify(error=message, hint=hint), 503


@app.errorhandler(ValueError)
def handle_value_error(err):
    return jsonify(error=str(err)), 400


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
def parse_date(value, field, required=True):
    if not value:
        if required:
            raise ValueError("%s is required." % field)
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date().isoformat()
    except ValueError:
        raise ValueError("%s must look like YYYY-MM-DD." % field)


def parse_time(value):
    try:
        return datetime.strptime(value or "", "%H:%M").strftime("%H:%M")
    except ValueError:
        raise ValueError("time must look like HH:MM.")


def parse_int(value, field):
    try:
        return int(value)
    except (TypeError, ValueError):
        raise ValueError("%s is required." % field)


# --------------------------------------------------------------------------
# Pages
# --------------------------------------------------------------------------
@app.get("/")
def home():
    return send_from_directory(app.static_folder, "index.html")


# --------------------------------------------------------------------------
# API (read)
# --------------------------------------------------------------------------
@app.get("/api/health")
def health():
    row = query(
        """
        SELECT @@SERVERNAME AS server, DB_NAME() AS [database],
               (SELECT COUNT(*) FROM Patients)     AS patients,
               (SELECT COUNT(*) FROM Doctors)      AS doctors,
               (SELECT COUNT(*) FROM Appointments) AS appointments
        """
    )[0]
    return jsonify(row)


@app.get("/api/dataset")
def dataset():
    """Everything the dashboard needs, read straight from SQL Server."""
    departments = query(
        "SELECT DepartmentID AS id, DepartmentName AS name, Location AS location "
        "FROM Departments ORDER BY DepartmentID"
    )
    doctors = query(
        "SELECT DoctorID AS id, FirstName AS [first], LastName AS [last], "
        "Specialization AS specialization, DepartmentID AS departmentId, "
        "ConsultationFee AS fee FROM Doctors ORDER BY DoctorID"
    )
    patients = query(
        "SELECT PatientID AS id, FirstName + ' ' + LastName AS name, "
        "DATEDIFF(YEAR, DateOfBirth, GETDATE()) AS age FROM Patients ORDER BY PatientID"
    )
    appointments = query(
        "SELECT AppointmentID AS id, PatientID AS patientId, DoctorID AS doctorId, "
        "AppointmentDate AS [date], AppointmentTime AS [time], Status AS status, "
        "VisitReason AS reason, CancellationReason AS cancelReason, "
        "TotalAmount AS total, AmountPaid AS paid, PaymentStatus AS paymentStatus "
        "FROM vw_AppointmentDetails ORDER BY AppointmentDate, AppointmentTime, AppointmentID"
    )
    return jsonify(
        departments=departments, doctors=doctors, patients=patients, appointments=appointments
    )


@app.get("/api/report/department")
def department_report():
    """Calls the stored procedure usp_DepartmentReport."""
    start = parse_date(request.args.get("start"), "start", required=False)
    end = parse_date(request.args.get("end"), "end", required=False)
    rows = query("EXEC usp_DepartmentReport @StartDate = ?, @EndDate = ?", (start, end))
    return jsonify(start=start, end=end, rows=rows)


# --------------------------------------------------------------------------
# API (write) - uses the stored procedures from the SQL script
# --------------------------------------------------------------------------
@app.post("/api/appointments")
def book_appointment():
    """Calls usp_BookAppointment (checks past dates and double booking)."""
    body = request.get_json(silent=True) or {}
    patient_id = parse_int(body.get("patientId"), "patientId")
    doctor_id = parse_int(body.get("doctorId"), "doctorId")
    appt_date = parse_date(body.get("date"), "date")
    appt_time = parse_time(body.get("time"))
    reason = (body.get("reason") or "").strip()[:100] or None

    with db() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC usp_BookAppointment @PatientID = ?, @DoctorID = ?, "
            "@ApptDate = ?, @ApptTime = ?, @VisitReason = ?",
            (patient_id, doctor_id, appt_date, appt_time, reason),
        )
        new_id = int(cur.fetchone()[0])
        conn.commit()
    return jsonify(appointmentId=new_id), 201


@app.post("/api/appointments/<int:appointment_id>/cancel")
def cancel_appointment(appointment_id):
    """Calls usp_CancelAppointment (only Scheduled appointments can be cancelled)."""
    body = request.get_json(silent=True) or {}
    reason = (body.get("reason") or "Patient request").strip()[:100]
    with db() as conn:
        cur = conn.cursor()
        cur.execute(
            "EXEC usp_CancelAppointment @AppointmentID = ?, @Reason = ?",
            (appointment_id, reason),
        )
        while cur.nextset():
            pass
        conn.commit()
    return jsonify(ok=True)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    print("Using driver:", pick_driver())
    print("Open http://127.0.0.1:%d" % port)
    app.run(host="127.0.0.1", port=port, debug=os.getenv("FLASK_DEBUG") == "1")
