"""Database utility functions for SQL Server connection management."""

import os
from dotenv import load_dotenv
import pyodbc


def load_connection_config():
    """
    Load database connection configuration from environment variables.

    Loads environment variables from .env file and creates connection
    dictionaries for both primary and replica databases.

    Returns:
        tuple: A tuple containing (primary_conn, replica_conn) dictionaries
               with connection parameters (server, database, username, password, driver)
    """
    load_dotenv()

    primary_conn = {
        'server': os.getenv('PRIMARY_SERVER'),
        'database': os.getenv('PRIMARY_DATABASE'),
        'username': os.getenv('PRIMARY_USERNAME'),
        'password': os.getenv('PRIMARY_PASSWORD'),
        'driver': os.getenv('PRIMARY_DRIVER'),
    }

    replica_conn = {
        'server': os.getenv('REPLICA_SERVER'),
        'database': os.getenv('REPLICA_DATABASE'),
        'username': os.getenv('REPLICA_USERNAME'),
        'password': os.getenv('REPLICA_PASSWORD'),
        'driver': os.getenv('REPLICA_DRIVER'),
    }

    return primary_conn, replica_conn


def get_connection_string(conn_info):
    """
    Generate ODBC connection string from connection info dictionary.

    Args:
        conn_info (dict): Dictionary containing connection parameters:
                         - driver: ODBC driver name
                         - server: Server name and optional port
                         - database: Database name
                         - username: Username for authentication
                         - password: Password for authentication

    Returns:
        str: Formatted ODBC connection string
    """
    return (
        f"DRIVER={conn_info['driver']};"
        f"SERVER={conn_info['server']};"
        f"DATABASE={conn_info['database']};"
        f"UID={conn_info['username']};"
        f"PWD={conn_info['password']}"
    )


def check_connection_info(conn_info, label):
    """
    Check if all required connection parameters are present.

    Args:
        conn_info (dict): Dictionary containing connection parameters
        label (str): Human-readable label for the database connection

    Returns:
        bool: True if all parameters are present and not empty, False otherwise
    """
    missing = [k for k, v in conn_info.items() if not v]
    if missing:
        print(
            f"Missing environment variables for {label}: {', '.join(missing)}")
        return False
    return True


def test_connection(conn_str, label):
    """
    Test database connection and return connection object if successful.

    Args:
        conn_str (str): ODBC connection string
        label (str): Human-readable label for the database connection

    Returns:
        pyodbc.Connection or None: Connection object if successful, None if failed

    Note:
        Prints connection status to console. Caller is responsible for closing
        the returned connection object.
    """
    print(f"Testing connection to {label}...")
    try:
        conn = pyodbc.connect(conn_str)
        print(f"✓ Successfully connected to {label}")
        return conn
    except pyodbc.Error as e:
        print(f"✗ Failed to connect to {label}: {e}")
        return None


def execute_query(conn_str, query, label, fetch_results=True):
    """
    Execute a query and optionally return results.

    Args:
        conn_str (str): ODBC connection string
        query (str): SQL query to execute
        label (str): Human-readable label for the database connection
        fetch_results (bool): If True, fetch and return query results.
                            If False, commit changes and return row count.

    Returns:
        list or int or None: 
            - If fetch_results=True: List of Row objects or None on error
            - If fetch_results=False: Number of affected rows or None on error
    """
    try:
        with pyodbc.connect(conn_str) as conn:
            cursor = conn.cursor()
            cursor.execute(query)

            if fetch_results:
                rows = cursor.fetchall()
                return rows
            else:
                conn.commit()
                return cursor.rowcount

    except pyodbc.Error as e:
        print(f"Database error executing query on {label}: {e}")
        return None


def insert_record_primary(conn_info, table_name, data):
    """
    Insert a record into a table in the primary database.

    Args:
        conn_info (dict): Primary database connection information
        table_name (str): Name of the table to insert into
        data (dict): Dictionary of column names and values to insert

    Returns:
        int or None: Number of rows inserted, or None on error
    """
    try:
        conn_str = get_connection_string(conn_info)
        
        # Build INSERT statement
        columns = ', '.join(data.keys())
        placeholders = ', '.join(['?' for _ in data])
        query = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
        
        with pyodbc.connect(conn_str) as conn:
            cursor = conn.cursor()
            cursor.execute(query, list(data.values()))
            conn.commit()
            print(f"Inserted record into {table_name} on primary DB.")
            return cursor.rowcount
            
    except pyodbc.Error as e:
        print(f"Database error inserting record: {e}")
        return None
    except Exception as e:
        print(f"Error inserting record: {e}")
        return None
