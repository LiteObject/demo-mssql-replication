"""
Script to read test data from primary and replica SQL Server databases.

This module connects to both primary and replica databases and reads data from
the TestData table to verify database connectivity and data consistency.
"""

import pyodbc
from db_utils import load_connection_config, get_connection_string, check_connection_info

# Load connection configurations
PRIMARY_CONN, REPLICA_CONN = load_connection_config()


def get_conn_str(conn_info):
    """
    Generate ODBC connection string from connection info dictionary.

    Args:
        conn_info (dict): Dictionary containing database connection parameters

    Returns:
        str: ODBC connection string
    """
    return get_connection_string(conn_info)


def check_conn_info(conn_info, label):
    """
    Check if all required connection parameters are present.

    Args:
        conn_info (dict): Dictionary containing database connection parameters
        label (str): Human-readable label for the database connection

    Returns:
        bool: True if all parameters are present, False otherwise
    """
    return check_connection_info(conn_info, label)


def read_testdata(conn_str, label):
    """
    Read test data from the TestData table and display results.

    Args:
        conn_str (str): ODBC connection string for the database
        label (str): Human-readable label for the database (for display purposes)

    Returns:
        None: Prints results to console
    """
    print(f"\nReading from {label}...")
    try:
        with pyodbc.connect(conn_str) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT Id, Value, CreatedAt FROM dbo.TestData')
            rows = cursor.fetchall()
            if not rows:
                print("No rows found.")
            for row in rows:
                print(
                    f"Id: {row.Id}, Value: {row.Value}, CreatedAt: {row.CreatedAt}")
            print(f"Total rows: {len(rows)}")
    except pyodbc.Error as e:
        print(f"Database error reading {label}: {e}")
    except Exception as e:
        print(f"Unexpected error reading {label}: {e}")


if __name__ == "__main__":
    if check_conn_info(PRIMARY_CONN, "Primary DB"):
        read_testdata(get_conn_str(PRIMARY_CONN), "Primary DB")
    if check_conn_info(REPLICA_CONN, "Replica DB"):
        read_testdata(get_conn_str(REPLICA_CONN), "Replica DB")
