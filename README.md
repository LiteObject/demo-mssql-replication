# demo-mssql-replication

A demonstration project for SQL Server database setup with Docker, featuring primary and replica database containers with transactional replication for testing database connectivity and replication operations.

## Features

- **Docker Compose Setup**: Easy deployment of SQL Server primary and replica instances
- **Transactional Replication**: Real-time data synchronization between primary and replica
- **Database Utilities**: Python utilities for database connection and operations
- **Replication Verification**: Automated testing of replication functionality
- **Adminer Integration**: Web-based database administration interface
- **Environment Configuration**: Flexible configuration via environment variables

## Quick Start

1. **Clone and Setup**:
   ```bash
   git clone <repository-url>
   cd demo-mssql-replication
   ```

2. **Start Services with Automatic Replication**:
   ```bash
   docker-compose up -d
   ```
   
   **Note**: The containers will automatically set up replication during startup. This process takes about 90 seconds:
   - Both containers start and initialize SQL Server (~30 seconds)
   - Replica container creates the subscriber database and table
   - Publisher container waits for subscriber to be ready
   - Publisher creates the distributor, publication, and subscription
   - Snapshot agent job is automatically started during setup
   - Replication agents are started automatically
   - You can monitor progress with: `docker-compose logs -f`

3. **Wait for Initialization** (Recommended):
   ```bash
   # Wait for all containers to be ready
   docker-compose logs -f mssql
   # Look for "Initialization script completed" and "Subscription and push subscription agent created successfully"
   ```

4. **Test Replication**:
   ```bash
   python verify_replication.py
   ```

5. **Test After Container Restart** (Optional):
   ```bash
   # Test that replication works after a complete restart
   python test_after_restart.py
   ```

6. **Manual Setup** (Only if automatic setup fails):
   
   **Option A - Using setup script:**
   ```bash
   # Linux/macOS
   chmod +x setup_replication.sh
   ./setup_replication.sh
   
   # Windows PowerShell
   .\setup_replication.ps1
   ```
   
   **Option B - Manual execution:**
   ```bash
   # Copy and run the setup script manually
   docker cp setup_replication.sql mssql_test:/tmp/
   docker exec -it mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -C -i "/tmp/setup_replication.sql" -v IS_PUBLISHER="true"
   ```

7. **Access Adminer**: http://localhost:8080
   - Server: `localhost:1433` (primary) or `localhost:1434` (replica)
   - Username: `SA`
   - Password: `YourStrong!Passw0rd`
   - Database: `MyDatabase`

## How SQL Server Replication Works

### Replication Architecture

SQL Server transactional replication follows a publisher-distributor-subscriber model:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PUBLISHER     │    │   DISTRIBUTOR   │    │   SUBSCRIBER    │
│  (mssql_test)   │    │  (mssql_test)   │    │ (mssql_replica) │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ MyDatabase  │ │    │ │distribution │ │    │ │ MyDatabase  │ │
│ │ └─TestData  │ │    │ │  database   │ │    │ │ └─TestData  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │     Log Reader         │    Distribution        │
         │        Agent           │       Agent            │
         └────────────────────────┼────────────────────────┘
                                  │
                            ┌─────────────┐
                            │   Snapshot  │
                            │    Agent    │
                            └─────────────┘
```

### Replication Process

1. **Transaction Capture**: When data changes occur on the publisher, the Log Reader Agent scans the transaction log and captures committed transactions.

2. **Distribution Storage**: Captured transactions are stored in the distribution database as replication commands.

3. **Data Delivery**: The Distribution Agent reads commands from the distribution database and applies them to the subscriber.

4. **Initial Synchronization**: The Snapshot Agent creates an initial copy of the published data to synchronize new subscriptions.

### Key Components

#### **Publisher** (`mssql_test`)
- Contains the source database with original data
- Publishes the `TestData` table as part of `MyDatabasePublication`
- Hosts the Log Reader Agent that captures transaction log changes

#### **Distributor** (`mssql_test` - same server)
- Stores replication metadata and commands in the `distribution` database
- Hosts the Distribution Agent that delivers changes to subscribers
- Manages replication history and retention policies

#### **Subscriber** (`mssql_replica`)
- Receives replicated data from the distributor
- Contains a copy of the `TestData` table kept in sync with the publisher
- Typically read-only to prevent conflicts

#### **Replication Agents**
- **Log Reader Agent**: Monitors publisher transaction log for changes
- **Distribution Agent**: Delivers changes from distributor to subscriber
- **Snapshot Agent**: Creates initial data snapshots for new subscriptions

## Project Files Overview

### Core Configuration Files

#### `docker-compose.yml`
Defines the multi-container Docker application with:
- **mssql_test**: Primary SQL Server container (Publisher/Distributor)
- **mssql_replica**: Replica SQL Server container (Subscriber)
- **adminer**: Web-based database management interface
- **Networking**: Internal Docker network for inter-container communication

#### `setup_replication.sh` / `setup_replication.ps1`
Automated setup scripts for replication:
- **Cross-platform**: Bash script for Linux/macOS, PowerShell for Windows
- **Container validation**: Checks if both containers are running
- **Automated execution**: Copies and runs the SQL setup script
- **Error handling**: Provides clear success/failure messages

#### `setup_replication.sql`
The main replication configuration script that:
- Enables SQL Server Agent (required for replication)
- Configures the distributor and creates the distribution database
- Creates the `MyDatabase` and `TestData` table
- Sets up the publication and article (table to replicate)
- Configures the subscription with proper authentication
- Creates and starts the snapshot agent job

### Database Initialization Files

#### `init_db.sql`
Initial database setup script that:
- Creates the `MyDatabase` database
- Creates the `TestData` table with proper schema
- Inserts initial test data

#### `init-db.sh`
Shell script for container initialization that:
- Waits for SQL Server to be ready
- Executes the `init_db.sql` script
- Handles SSL certificate trust for SQL Server 2022

#### `create_test_table.sql`
Standalone script to create the `TestData` table:
- Defines the table structure with Identity column
- Sets up default values and constraints

#### `enable_cdc_primary.sql`
Script to enable Change Data Capture (CDC) on the primary database:
- Enables CDC at database level
- Configures CDC for the `TestData` table
- Alternative to transactional replication for change tracking

### Python Utilities

#### `db_utils.py`
Core database utility module providing:
- **Connection Management**: Functions to load and validate connection configurations
- **Connection String Generation**: Creates ODBC connection strings from configuration
- **Connection Testing**: Validates database connectivity
- **Environment Variable Support**: Loads configuration from environment variables

#### `read_testdata.py`
Database connectivity test script that:
- Tests connections to both primary and replica databases
- Reads and displays data from the `TestData` table
- Verifies that the database setup is working correctly

#### `verify_replication.py`
Replication verification script that:
- Inserts a test record into the primary database
- Waits for replication to occur (10-second delay)
- Checks if the record appears in the replica database
- Reports whether replication is working correctly

#### `test_after_restart.py`
Comprehensive test script for container restart scenarios:
- Waits for containers to be ready after restart
- Tests database connectivity to both primary and replica
- Performs end-to-end replication verification
- Provides detailed success/failure reporting

### Support Files

#### `create_replication_directory.sh`
Shell script to create the required replication directory:
- Creates `/var/opt/mssql/ReplData` directory
- Sets proper ownership and permissions for SQL Server
- Required for replication agents to function

#### `replication_fixes.ps1`
PowerShell documentation script containing:
- Manual fixes that were applied to make replication work
- Troubleshooting commands for common replication issues
- SQL commands to update replication configuration

#### `README.md`
This documentation file explaining:
- Project overview and setup instructions
- How SQL Server replication works
- Detailed explanation of each file's purpose
- Troubleshooting and configuration guidance

## Replication Configuration Details

### Authentication
- **Publisher to Distributor**: Windows Authentication (same server)
- **Distributor to Subscriber**: SQL Server Authentication with SA credentials
- **Reason**: Cross-container communication requires SQL authentication

### Network Configuration
- **Primary Container**: `mssql_test` on port 1433
- **Replica Container**: `mssql_replica` on port 1434
- **Internal Network**: Docker Compose creates isolated network for container communication

### Data Synchronization
- **Replication Type**: Transactional replication
- **Sync Mode**: Continuous (near real-time)
- **Initial Sync**: Snapshot agent creates initial data copy
- **Ongoing Sync**: Log Reader Agent captures changes, Distribution Agent delivers them

### Troubleshooting
If replication fails, check:
1. Replication directory exists: `/var/opt/mssql/ReplData`
2. Distribution agent is running: Check job status in `msdb.dbo.sysjobs`
3. Network connectivity between containers
4. SQL Server Agent is enabled and running
5. Server names are case-sensitive: use `mssql_replica` not `MSSQL_REPLICA`

## Database Utilities

The `db_utils.py` module provides helper functions for database operations:

### Core Functions

#### `load_connection_config()`
Loads database connection configurations from environment variables.

**Returns:**
- `tuple`: (primary_conn, replica_conn) dictionaries with connection parameters

#### `get_connection_string(conn_info)`
Generates ODBC connection strings from connection info dictionaries.

**Args:**
- `conn_info` (dict): Dictionary containing connection parameters

**Returns:**
- `str`: Formatted ODBC connection string

#### `check_connection_info(conn_info, label)`
Validates that all required connection parameters are present.

**Args:**
- `conn_info` (dict): Dictionary containing connection parameters
- `label` (str): Human-readable label for the database connection

**Returns:**
- `bool`: True if all parameters are present, False otherwise

#### `test_connection(conn_str, label)`
Tests database connections and provides feedback.

**Args:**
- `conn_str` (str): ODBC connection string
- `label` (str): Human-readable label for the database connection

**Returns:**
- `pyodbc.Connection` or `None`: Connection object if successful, None if failed

#### `execute_query(conn_str, query, label, fetch_results=True)`
Executes queries with error handling.

**Args:**
- `conn_str` (str): ODBC connection string
- `query` (str): SQL query to execute
- `label` (str): Human-readable label for the database connection
- `fetch_results` (bool): If True, fetch and return query results

**Returns:**
- `list` or `int` or `None`: Query results, row count, or None on error

#### `insert_record_primary(conn_info, table_name, data)`
Inserts records into the primary database.

**Args:**
- `conn_info` (dict): Primary database connection information
- `table_name` (str): Name of the table to insert into
- `data` (dict): Dictionary of column names and values to insert

**Returns:**
- `int` or `None`: Number of rows inserted, or None on error

### Example Usage

```python
from db_utils import load_connection_config, get_connection_string, test_connection

# Load connection info
PRIMARY_CONN, REPLICA_CONN = load_connection_config()

# Test connectivity
conn_str = get_connection_string(PRIMARY_CONN)
conn = test_connection(conn_str, "Primary DB")
if conn:
    print("Connection successful!")
    conn.close()
```

## Environment Variables

The project uses the following environment variables for configuration:

### Database Connection Variables
- `PRIMARY_SERVER`: Primary database server (default: localhost)
- `PRIMARY_PORT`: Primary database port (default: 1433)
- `PRIMARY_DATABASE`: Primary database name (default: MyDatabase)
- `PRIMARY_USERNAME`: Primary database username (default: SA)
- `PRIMARY_PASSWORD`: Primary database password (default: YourStrong!Passw0rd)

- `REPLICA_SERVER`: Replica database server (default: localhost)
- `REPLICA_PORT`: Replica database port (default: 1434)
- `REPLICA_DATABASE`: Replica database name (default: MyDatabase)
- `REPLICA_USERNAME`: Replica database username (default: SA)
- `REPLICA_PASSWORD`: Replica database password (default: YourStrong!Passw0rd)

### Docker Configuration
Set these variables in your environment or create a `.env` file in the project root:

```env
# Primary Database
PRIMARY_SERVER=localhost
PRIMARY_PORT=1433
PRIMARY_DATABASE=MyDatabase
PRIMARY_USERNAME=SA
PRIMARY_PASSWORD=YourStrong!Passw0rd

# Replica Database
REPLICA_SERVER=localhost
REPLICA_PORT=1434
REPLICA_DATABASE=MyDatabase
REPLICA_USERNAME=SA
REPLICA_PASSWORD=YourStrong!Passw0rd
```

## Performance Considerations

### Replication Latency
- **Typical Latency**: 10-15 seconds for transaction replication
- **Factors Affecting Latency**:
  - Network latency between containers
  - Transaction log scan frequency
  - Distribution agent polling interval
  - Size and complexity of transactions

### Monitoring Replication
Use these queries to monitor replication performance:

```sql
-- Check pending commands in distribution database
USE distribution;
SELECT COUNT(*) AS PendingCommands 
FROM MSrepl_commands 
WHERE article_id = 1 AND publisher_database_id = 1;

-- Check distribution agent status
SELECT agent_id, comments, time, runstatus 
FROM MSdistribution_history 
WHERE agent_id = 4 
ORDER BY time DESC;

-- Check replication jobs
USE msdb;
SELECT name, enabled, date_created 
FROM dbo.sysjobs 
WHERE name LIKE '%MyDatabasePublication%';
```

## Security Considerations

### Authentication
- **Production**: Use Windows Authentication or dedicated SQL Server accounts
- **Development**: SA account is acceptable for testing
- **Cross-Container**: SQL Server authentication required for Docker networking

### Network Security
- **Internal Network**: Containers communicate via Docker's internal network
- **Port Exposure**: Only necessary ports are exposed to the host
- **SSL/TLS**: SQL Server connections use encryption (`-C` flag in sqlcmd)

### Data Protection
- **Backup Strategy**: Implement regular backups of both primary and replica
- **Recovery Planning**: Document recovery procedures for replication failures
- **Monitoring**: Set up alerts for replication agent failures

## Development and Testing

### Running Tests
```bash
# Test basic connectivity
python read_testdata.py

# Test replication functionality
python verify_replication.py

# Check container logs
docker logs mssql_test
docker logs mssql_replica
```

### Debugging Replication Issues
```bash
# Check replication agent jobs
docker exec -it mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -C -Q "USE msdb; SELECT name, enabled FROM dbo.sysjobs WHERE name LIKE '%replication%';"

# Check distribution agent history
docker exec -it mssql_test /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStrong!Passw0rd' -C -Q "USE distribution; SELECT TOP 10 agent_id, comments, time, runstatus FROM MSdistribution_history ORDER BY time DESC;"
```

## License

This project is provided as-is for educational and demonstration purposes. Modify and use according to your needs.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues or questions:
1. Check the troubleshooting section in this README
2. Review the replication agent logs
3. Consult SQL Server replication documentation
4. Create an issue in the repository
    print("Connected successfully!")
    conn.close()

# Insert data example
data = {"Value": "Test record", "CreatedAt": "2025-01-01"}
result = insert_record_primary(PRIMARY_CONN, "TestData", data)
if result:
    print(f"Inserted {result} record(s)")
```

## Database Schema

The demo includes a `TestData` table with the following structure:

```sql
CREATE TABLE TestData (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Value NVARCHAR(255),
    CreatedAt DATETIME2 DEFAULT GETDATE()
);
```

## Environment Configuration

Create a `.env` file with your database connection settings:

```env
# Primary Database
PRIMARY_SERVER=localhost,1433
PRIMARY_DATABASE=MyDatabase
PRIMARY_USERNAME=SA
PRIMARY_PASSWORD=YourStrong!Passw0rd
PRIMARY_DRIVER={ODBC Driver 17 for SQL Server}

# Replica Database
REPLICA_SERVER=localhost,1434
REPLICA_DATABASE=MyDatabase
REPLICA_USERNAME=SA
REPLICA_PASSWORD=YourStrong!Passw0rd
REPLICA_DRIVER={ODBC Driver 17 for SQL Server}
```

## Important Notes

### Database Independence
- **Separate Instances**: Primary and replica are independent SQL Server instances
- **No Automatic Replication**: Changes to primary do not automatically appear in replica
- **Manual Operations**: Use provided utilities to insert/read data from each database independently

### Container Setup
- **Primary Container**: Exposed on port 1433
- **Replica Container**: Exposed on port 1434
- **Adminer**: Available on port 8080 for database management
- **Initialization**: Both containers automatically create the MyDatabase and TestData table on startup

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Primary DB    │    │   Replica DB    │
│   (port 1433)   │    │   (port 1434)   │
│                 │    │                 │
│   MyDatabase    │    │   MyDatabase    │
│   └─TestData    │    │   └─TestData    │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
            ┌─────────────────┐
            │    Adminer      │
            │   (port 8080)   │
            └─────────────────┘
```

## Usage Examples

### Reading Data
```python
# Run the test script
python read_testdata.py
```

### Inserting Data
Uncomment the insertion code in `read_testdata.py` and run:
```python
python read_testdata.py
```

### Custom Operations
```python
from db_utils import load_connection_config, execute_query, get_connection_string

primary_conn, replica_conn = load_connection_config()
primary_str = get_connection_string(primary_conn)

# Execute custom query
results = execute_query(primary_str, "SELECT COUNT(*) FROM TestData", "Primary DB")
if results:
    print(f"Total records: {results[0][0]}")
```

## Troubleshooting

### Connection Issues
- Ensure containers are running: `docker-compose ps`
- Check container logs: `docker-compose logs mssql` or `docker-compose logs mssql_replica`
- Verify environment variables in `.env` file
- Test with Adminer web interface first

### Database Not Found
- Wait for containers to fully initialize (can take 90+ seconds)
- Check if initialization scripts ran successfully in container logs
- Manually create database if needed via Adminer

### SQL Server Authentication
- Default SA password: `YourStrong!Passw0rd`
- Ensure SQL Server authentication is enabled (configured in Docker setup)
- Check firewall/networking if connecting from external machines

## Development

### Adding New Utilities
Add new database utility functions to `db_utils.py` following the established patterns:
- Include comprehensive docstrings
- Handle errors gracefully with try/except blocks
- Return consistent data types (None on error)
- Print informative messages for debugging

### Testing
Use `read_testdata.py` to verify:
- Database connectivity to both primary and replica
- Data insertion functionality
- Query execution and result retrieval

## Project Structure

```
demo-mssql-replication/
├── docker-compose.yml          # Container orchestration
├── Dockerfile.mssql           # Custom SQL Server image
├── init-db.sh                 # Database initialization script
├── init_db.sql               # Database creation SQL
├── create_test_table.sql     # Test table creation
├── .env                      # Environment variables
├── db_utils.py              # Database utility functions
├── read_testdata.py         # Test script for connectivity
└── README.md               # This documentation
```
