#!/bin/bash
# Wait for SQL Server to start
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "WAITFOR DELAY '00:00:10'"

# Run the initialization script
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -i /init_db.sql
