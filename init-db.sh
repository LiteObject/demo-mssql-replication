#!/bin/bash
set -e

echo "=== Database Initialization Script Starting ==="

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
for i in {1..60}; do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "SELECT 1" -C > /dev/null 2>&1; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting... ($i/60)"
    sleep 5
done

# Verify SQL Server is responsive
echo "Testing SQL Server connection..."
/opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "SELECT @@VERSION" -C

if [ $? -eq 0 ]; then
    echo "=== Running database initialization ==="
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -i /init_db.sql -C
    
    if [ $? -eq 0 ]; then
        echo "=== Database initialization completed successfully! ==="
        
        # Verify database was created
        echo "=== Verifying MyDatabase was created ==="
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "SELECT name FROM sys.databases WHERE name = 'MyDatabase'" -C
        
        # Create replication directory (required for replication agents)
        echo "=== Creating replication directory ==="
        mkdir -p /var/opt/mssql/ReplData
        chown mssql:mssql /var/opt/mssql/ReplData
        chmod 755 /var/opt/mssql/ReplData
        echo "Replication directory created successfully at /var/opt/mssql/ReplData"
        echo "Owner: $(ls -ld /var/opt/mssql/ReplData | awk '{print $3":"$4}')"
        echo "Permissions: $(ls -ld /var/opt/mssql/ReplData | awk '{print $1}')"
        
        # Run replication setup based on container role
        if [ -f "/setup_replication.sql" ]; then
            if [ "${IS_PUBLISHER}" = "true" ]; then
                echo "=== Running replication setup (Publisher) ==="
                echo "Waiting for subscriber to be ready..."
                sleep 60  # Wait longer for subscriber to be fully ready
                /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -i /setup_replication.sql -v IS_PUBLISHER="true" -C || echo "Replication setup failed (continuing)"
            else
                echo "=== Setting up subscriber database ==="
                sleep 10  # Basic delay for SQL Server readiness
                # Create database and table for subscriber (this is NOT the publisher)
                /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P YourStrong!Passw0rd -Q "
                    IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'MyDatabase')
                    BEGIN
                        CREATE DATABASE [MyDatabase];
                        PRINT 'MyDatabase created on subscriber';
                    END
                    USE [MyDatabase];
                    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TestData]') AND type in (N'U'))
                    BEGIN
                        CREATE TABLE [dbo].[TestData](
                            [Id] [int] IDENTITY(1,1) PRIMARY KEY,
                            [Value] [nvarchar](255) NULL,
                            [CreatedAt] [datetime2](7) DEFAULT GETDATE() NULL
                        );
                        PRINT 'TestData table created on subscriber';
                    END
                " -C || echo "Subscriber setup failed (continuing)"
            fi
        fi
    else
        echo "=== Database initialization FAILED! ==="
        exit 1
    fi
else
    echo "=== SQL Server connection test FAILED! ==="
    exit 1
fi

echo "=== Initialization script completed ==="