# SQL Server Replication Setup Script (PowerShell)
# This script sets up transactional replication between SQL Server containers

Write-Host "=== SQL Server Replication Setup ===" -ForegroundColor Green
Write-Host "Setting up replication between mssql_test (primary) and mssql_replica (replica)" -ForegroundColor Cyan

# Check if containers are running
Write-Host "Checking if containers are running..." -ForegroundColor Yellow
$primaryRunning = docker ps --format "table {{.Names}}" | Select-String "mssql_test"
$replicaRunning = docker ps --format "table {{.Names}}" | Select-String "mssql_replica"

if (-not $primaryRunning) {
    Write-Host "ERROR: mssql_test container is not running" -ForegroundColor Red
    exit 1
}

if (-not $replicaRunning) {
    Write-Host "ERROR: mssql_replica container is not running" -ForegroundColor Red
    exit 1
}

Write-Host "Both containers are running" -ForegroundColor Green

# Copy setup script to container
Write-Host "Copying setup_replication.sql to container..." -ForegroundColor Yellow
docker cp setup_replication.sql mssql_test:/tmp/

# Run replication setup
Write-Host "Running replication setup script..." -ForegroundColor Yellow
docker exec -it mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -C -i "/tmp/setup_replication.sql" -v IS_PUBLISHER="true"

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Replication setup completed successfully! ===" -ForegroundColor Green
    Write-Host "You can now test replication by running: python verify_replication.py" -ForegroundColor Cyan
} else {
    Write-Host "=== Replication setup failed! ===" -ForegroundColor Red
    exit 1
}
