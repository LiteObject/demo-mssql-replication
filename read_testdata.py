import os
from dotenv import load_dotenv
import pyodbc

# Load environment variables from .env file
load_dotenv()

# Get connection info for primary and replica
PRIMARY_CONN = {
    'server': os.getenv('PRIMARY_SERVER'),
    'database': os.getenv('PRIMARY_DATABASE'),
    'username': os.getenv('PRIMARY_USERNAME'),
    'password': os.getenv('PRIMARY_PASSWORD'),
    'driver': os.getenv('PRIMARY_DRIVER'),
}
REPLICA_CONN = {
    'server': os.getenv('REPLICA_SERVER'),
    'database': os.getenv('REPLICA_DATABASE'),
    'username': os.getenv('REPLICA_USERNAME'),
    'password': os.getenv('REPLICA_PASSWORD'),
    'driver': os.getenv('REPLICA_DRIVER'),
}

def get_conn_str(conn_info):
    return (
        f"DRIVER={conn_info['driver']};"
        f"SERVER={conn_info['server']};"
        f"DATABASE={conn_info['database']};"
        f"UID={conn_info['username']};"
        f"PWD={conn_info['password']}"
    )

def read_testdata(conn_str, label):
    print(f"\nReading from {label}...")
    try:
        with pyodbc.connect(conn_str) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT Id, Value, CreatedAt FROM dbo.TestData')
            rows = cursor.fetchall()
            for row in rows:
                print(f"Id: {row.Id}, Value: {row.Value}, CreatedAt: {row.CreatedAt}")
    except Exception as e:
        print(f"Error reading {label}: {e}")

if __name__ == "__main__":
    read_testdata(get_conn_str(PRIMARY_CONN), "Primary DB")
    read_testdata(get_conn_str(REPLICA_CONN), "Replica DB")
