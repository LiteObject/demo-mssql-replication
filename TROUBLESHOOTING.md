# Troubleshooting SQL Server Replication in Docker

If replication is not working (for example, if `verify_replication.py` reports 'Record not found in replica database'), use the following steps to diagnose and fix common issues.

---

## 1. Start the Snapshot Agent Job

If the snapshot agent job did not start automatically, you can start it manually. Replace the job name if you changed your database or publication names.

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "EXEC msdb.dbo.sp_start_job @job_name = 'MSSQL_TEST-MyDatabase-MyPublication-1'"
```

---

## 2. Check Job Status

Check if the snapshot agent job is running or not:

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "SELECT sj.name, CASE WHEN ja.start_execution_date IS NOT NULL AND ja.stop_execution_date IS NULL THEN 'Running' ELSE 'Not Running' END AS job_status FROM msdb.dbo.sysjobs sj LEFT JOIN msdb.dbo.sysjobactivity ja ON sj.job_id = ja.job_id WHERE sj.name = 'MSSQL_TEST-MyDatabase-MyPublication-1' AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity WHERE job_id = sj.job_id);"
```

---

## 3. Check SQL Server Agent Service Status

Make sure the SQL Server Agent is running (required for replication jobs):

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "SELECT CASE WHEN EXISTS (SELECT * FROM sys.dm_exec_sessions WHERE program_name LIKE 'SQLAgent%') THEN 'SQL Server Agent is running' ELSE 'SQL Server Agent is not running' END AS agent_status;"
```

---

## 4. Check Container Logs for Errors

View the SQL Server container logs for error messages or failed job attempts:

```bash
docker logs mssql_test | tail -n 100
```

---

## 5. More Help

- See the `README.md` for setup and architecture details.
- For advanced debugging, use the provided debug scripts:
  - `debug_job_startup.py` (Python)
  - `debug_startup_timing.sql` (SQL)
  - `test_automatic_startup.sql` (SQL)
- If you still have issues, check SQL Server system tables (`msdb.dbo.sysjobs`, `msdb.dbo.sysjobhistory`) for more details.