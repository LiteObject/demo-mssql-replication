
#!/bin/bash
set -e

# Wait for SQL Server to start up
for i in {1..30}; do
    /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "SELECT 1" && break
    echo "Waiting for SQL Server to be available..."
    sleep 2
done

# Run the initialization script
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -i /init_db.sql
