import pandas as pd
import mysql.connector
from pathlib import Path
from dotenv import load_dotenv
import os


# 1. Project path

project_path = (
    Path.home()
    / "Desktop"
    / "Supply Chain Disruption Intelligence"
)
load_dotenv(project_path / ".env")

# 2. MySQL connection

connection = mysql.connector.connect(
    host=os.getenv("MYSQL_HOST", "127.0.0.1"),
    port=int(os.getenv("MYSQL_PORT", 3306)),
    user=os.getenv("MYSQL_USER"),
    password=os.getenv("MYSQL_PASSWORD"),
    database=os.getenv("MYSQL_DATABASE", "supply_chain_intelligence")
)


# 3. Reusable loading function

def load_data(df, table_name, columns):

    cursor = connection.cursor()

    column_list = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))

    insert_query = f"""
        INSERT IGNORE INTO {table_name} ({column_list})
        VALUES ({placeholders})
    """

    records = list(
        df[columns].itertuples(index=False, name=None)
    )

    cursor.executemany(insert_query, records)

    connection.commit()

    print(f"{table_name}: {cursor.rowcount} rows inserted")

    cursor.close()


# 4. Load Suppliers

suppliers_df = pd.read_csv(
    project_path / "Data" / "processed" / "suppliers.csv"
)

suppliers_df = suppliers_df.astype(object).where(
    pd.notna(suppliers_df), None
)

load_data(
    suppliers_df,
    "suppliers",
    [
        "supplier_id",
        "supplier_name",
        "country",
        "region",
        "on_time_delivery_rate",
        "certification_level",
        "preferred_supplier_flag"
    ]
)

# 5. Load Sales

sales_df = pd.read_csv(
    project_path / "data" / "processed" / "sales.csv"
)

sales_df = sales_df.astype(object).where(
    pd.notna(sales_df), None
)

load_data(
    sales_df,
    "sales",
    [
        "order_id",
        "customer_id",
        "product_id",
        "order_date",
        "order_status",
        "order_quantity",
        "unit_price",
        "discount",
        "shipping_mode",
        "shipping_carrier",
        "shipping_date_scheduled",
        "shipping_date_actual",
        "delivery_status",
        "late_delivery_risk_flag",
        "vat_rate",
        "cogs",
        "unit_price_effective",
        "order_total",
        "vat_amount",
        "profit_per_order"
    ]
)
# 6load procurement
procurement_df = pd.read_csv(
    project_path / "Data" / "processed" / "procurement.csv"
)

procurement_df = procurement_df.astype(object).where(
    pd.notna(procurement_df), None
)

load_data(
    procurement_df,
    "procurement",
    [
        "po_id",
        "supplier_id",
        "raw_material_id",
        "order_date",
        "order_quantity",
        "unit_cost",
        "delivery_date_planned",
        "delivery_date_actual",
        "total_cost"
    ]
)

# 7. Close MySQL connection

connection.close()

print("MySQL connection closed.")
