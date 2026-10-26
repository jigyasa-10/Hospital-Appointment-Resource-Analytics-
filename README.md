# Hospital Appointment & Resource Analytics

A full-stack mini project: **SQL Server (SSMS) database + Python Flask API + web dashboard**.

```
Browser dashboard  <--JSON-->  Flask (app.py)  <--ODBC / pyodbc-->  SQL Server: HospitalAnalytics
 static/index.html              /api/...                            tables, view, stored procedures
```

## What each part does

| Part | File | Role |
|------|------|------|
| Database | `database/Hospital_Analytics_Full_Project.sql` | Creates the database, 5 tables, synthetic data, 3 views, 5 stored procedures, and 30+ analytics queries |
| Backend | `app.py` | Connects to SQL Server with pyodbc and exposes a JSON API |
| Frontend | `static/index.html` | Dashboard: charts, KPI cards, appointment table, booking form, department report |

The dashboard reads from the view `vw_AppointmentDetails`, runs the stored procedure `usp_DepartmentReport` for the report card, and calls `usp_BookAppointment` and `usp_CancelAppointment` for booking and cancelling.

## Requirements

1. **SQL Server + SSMS** (Express edition is fine)
2. **Python 3.9 or newer** (tick "Add Python to PATH" when installing)
3. **Microsoft ODBC Driver 17 or 18 for SQL Server**
   (search "Download ODBC Driver for SQL Server" on microsoft.com)

## Setup (one time)

**Step 1 - Create the database.** Open `database/Hospital_Analytics_Full_Project.sql` in SSMS and press **F5**. Refresh *Databases* and check that `HospitalAnalytics` exists.

**Step 2 - Find your server name.** It is the *Server name* in the SSMS "Connect to Server" box, for example `localhost`, `.\SQLEXPRESS` or `DESKTOP-ABC123\SQLEXPRESS`. You can also run `SELECT @@SERVERNAME;` in SSMS.

**Step 3 - Configure.** Copy `.env.example` to `.env` and set `DB_SERVER`.
- Windows Authentication (default in SSMS): leave `DB_USER` and `DB_PASSWORD` empty.
- SQL Server Authentication: fill `DB_USER` and `DB_PASSWORD`.

**Step 4 - Install and run.**

Easiest on Windows: double-click **`run.bat`**.

Or in a terminal inside this folder:

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Open **http://127.0.0.1:5000**. The pill at the top right shows **Connected - HospitalAnalytics on <server>** when everything works.

## API

| Method | URL | What it does |
|--------|-----|--------------|
| GET | `/api/health` | Server name, database name and row counts |
| GET | `/api/dataset` | Departments, doctors, patients and appointments (from `vw_AppointmentDetails`) |
| GET | `/api/report/department?start=YYYY-MM-DD&end=YYYY-MM-DD` | Runs `usp_DepartmentReport` |
| POST | `/api/appointments` | Runs `usp_BookAppointment` (rejects past dates and double booking) |
| POST | `/api/appointments/<id>/cancel` | Runs `usp_CancelAppointment` (only Scheduled ones) |

## How to demo it

1. In SSMS, show the tables and the database diagram (right-click *Database Diagrams* > New).
2. Run a few queries from the analytics section (monthly trend, department workload, cancellation rate, revenue).
3. Open the dashboard and point out that the numbers match the queries.
4. Use the department dropdown, the workload toggle (Visits / Revenue / Cancel %) and the table search.
5. Book an appointment in the form, then in SSMS run:
   `SELECT TOP 3 * FROM Appointments ORDER BY AppointmentID DESC;`
   The new row is there, which proves the website writes to the database.
6. Try booking the same doctor and time again to show the double-booking check (the procedure's error message appears in the form).
7. Cancel an upcoming appointment and show `Status = 'Cancelled'` in SSMS.
8. Run the Department report card and show it equals `EXEC usp_DepartmentReport` in SSMS.

## Troubleshooting

| Message | Fix |
|---------|-----|
| `Data source name not found` or driver error | Install the Microsoft ODBC Driver 17/18 for SQL Server. If you have both, set `DB_DRIVER=ODBC Driver 17 for SQL Server` in `.env` |
| `Login failed for user` | Using Windows auth? Leave `DB_USER` empty. Using SQL auth? Check the password and that SQL Server allows "SQL Server and Windows Authentication mode" |
| `Cannot open database "HospitalAnalytics"` | Run the SQL script in SSMS first (Step 1) |
| `Invalid object name 'vw_AppointmentDetails'` | The whole script was not executed. Run the full `.sql` file again |
| `A network-related or instance-specific error` | SQL Server is not running or the server name is wrong. Open *SQL Server Configuration Manager* and start the service, and check `DB_SERVER` |
| Port already in use | Change `PORT` in `.env` |

## Project structure

```
hospital_project/
  app.py                 Flask backend
  requirements.txt
  .env.example           copy to .env
  run.bat                one-click start (Windows)
  static/index.html      dashboard
  database/Hospital_Analytics_Full_Project.sql
```
