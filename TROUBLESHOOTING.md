### Start a SQL Server Agent job named MSSQL_TEST-MyDatabase-MyPublication-1:

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "EXEC msdb.dbo.sp_start_job @job_name = 'MSSQL_TEST-MyDatabase-MyPublication-1'"
```

### Command to Check Job Status

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "SELECT sj.name, CASE WHEN ja.start_execution_date IS NOT NULL AND ja.stop_execution_date IS NULL THEN 'Running' ELSE 'Not Running' END AS job_status FROM msdb.dbo.sysjobs sj LEFT JOIN msdb.dbo.sysjobactivity ja ON sj.job_id = ja.job_id WHERE sj.name = 'MSSQL_TEST-MyDatabase-MyPublication-1' AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity WHERE job_id = sj.job_id);"
```
### Command to check the SQL Server Agent’s status itself (to confirm it’s running):

```bash
docker exec mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourStrong!Passw0rd" -C -Q "SELECT CASE WHEN EXISTS (SELECT * FROM sys.dm_exec_sessions WHERE program_name LIKE 'SQLAgent%') THEN 'SQL Server Agent is running' ELSE 'SQL Server Agent is not running' END AS agent_status;"
```