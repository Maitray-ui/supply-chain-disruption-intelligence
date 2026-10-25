
# 1. Imports

import pandas as pd
import mysql.connector
from pathlib import Path
from dotenv import load_dotenv
import os


# 2. Project path

project_path = (
    Path.home()
    / "Desktop"
    / "Supply Chain Disruption Intelligence"
)


load_dotenv(project_path / ".env")

# 3. Connect to MySQL

connection = mysql.connector.connect(
    host=os.getenv("MYSQL_HOST", "127.0.0.1"),
    port=int(os.getenv("MYSQL_PORT", 3306)),
    user=os.getenv("MYSQL_USER"),
    password=os.getenv("MYSQL_PASSWORD"),
    database=os.getenv("MYSQL_DATABASE", "supply_chain_intelligence")
)

print("Connected to MySQL successfully!")


# 4. Check that the customers table exists

cursor = connection.cursor()

cursor.execute("SHOW TABLES")

print("Tables in the project database:")

for table in cursor.fetchall():
    print(table[0])


# 5. Close resources

cursor.close()
connection.close()

print("Connection closed.")
