#!/bin/bash

# SQL Server Replication Setup Script
# This script sets up transactional replication between SQL Server containers

echo "=== SQL Server Replication Setup ==="
echo "Setting up replication between mssql_test (primary) and mssql_replica (replica)"

# Check if containers are running
echo "Checking if containers are running..."
if ! docker ps | grep -q "mssql_test"; then
    echo "ERROR: mssql_test container is not running"
    exit 1
fi

if ! docker ps | grep -q "mssql_replica"; then
    echo "ERROR: mssql_replica container is not running"
    exit 1
fi

echo "Both containers are running"

# Copy setup script to container
echo "Copying setup_replication.sql to container..."
docker cp setup_replication.sql mssql_test:/tmp/

# Run replication setup
echo "Running replication setup script..."
docker exec -it mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -C -i "/tmp/setup_replication.sql" -v IS_PUBLISHER="true"

if [ $? -eq 0 ]; then
    echo "=== Replication setup completed successfully! ==="
    echo "You can now test replication by running: python verify_replication.py"
else
    echo "=== Replication setup failed! ==="
    exit 1
fi
