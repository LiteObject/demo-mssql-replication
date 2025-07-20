from db_utils import load_connection_config, get_connection_string, execute_query


def verify_replication():
    # Load connection configurations
    primary_conn, replica_conn = load_connection_config()

    # Get connection strings
    primary_str = get_connection_string(primary_conn)
    replica_str = get_connection_string(replica_conn)

    # Insert a test record into primary
    test_value = f"Replication test record - {__import__('datetime').datetime.now()}"
    insert_query = f"INSERT INTO TestData (Value) VALUES ('{test_value}')"

    print("Inserting test record into primary database...")
    execute_query(primary_str, insert_query, "Primary DB", fetch_results=False)

    # Wait a moment for replication to occur
    print("Waiting for replication to occur (10 seconds)...")
    __import__('time').sleep(10)

    # Check if the record appears in the replica
    select_query = f"SELECT Id, Value, CreatedAt FROM TestData WHERE Value = '{test_value}'"

    print("Checking primary database for the record...")
    primary_results = execute_query(primary_str, select_query, "Primary DB")

    print("Checking replica database for the record...")
    replica_results = execute_query(replica_str, select_query, "Replica DB")

    # Display results
    if primary_results and isinstance(primary_results, list) and len(primary_results) > 0:
        print(f"Record found in primary: {primary_results[0]}")
    else:
        print("Record not found in primary database!")

    if replica_results and isinstance(replica_results, list) and len(replica_results) > 0:
        print(f"Record found in replica: {replica_results[0]}")
        print("Replication is working correctly!")
    else:
        print("Record not found in replica database. Replication may not be working.")


if __name__ == "__main__":
    verify_replication()
