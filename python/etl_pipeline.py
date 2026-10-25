# Set up the paths and imports
import pandas as pd
from pathlib import Path

# Project directories
project_path = Path.home() / "Desktop" / "Supply Chain Disruption Intelligence"

raw_path = project_path / "data" / "raw"
processed_path = project_path / "data" / "processed"

# Create the processed folder if it doesn't exist
processed_path.mkdir(parents=True, exist_ok=True)

print("ETL pipeline initialized.")

# EXTRACT: Load raw CSV files

datasets = {
    "customers": pd.read_csv(raw_path / "customer_master.csv"),
    "products": pd.read_csv(raw_path / "product_master.csv"),
    "suppliers": pd.read_csv(raw_path / "supplier_master.csv"),
    "sales": pd.read_csv(raw_path / "sales_orders.csv"),
    "procurement": pd.read_csv(raw_path / "procurement_orders.csv")
}

for name, df in datasets.items():
    print(f"{name}: {df.shape[0]} rows, {df.shape[1]} columns")

# TRANSFORM: Standardize column names

for name, df in datasets.items():
    df.columns = (
        df.columns
        .str.strip()
        .str.lower()
        .str.replace(r"\s+", "_", regex=True)
    )

    print(f"{name}: column names standardized")

# TRANSFORM: Convert date columns

date_columns = {
    "products": ["launch_date", "discontinuation_date"],
    "sales": [
        "order_date",
        "shipping_date_scheduled",
        "shipping_date_actual"
    ],
    "procurement": [
        "order_date",
        "delivery_date_planned",
        "delivery_date_actual"
    ]
}

for name, columns in date_columns.items():
    df = datasets[name]

    for col in columns:
        df[col] = pd.to_datetime(df[col], errors="coerce")

    print(f"{name}: date columns converted")

# VALIDATE: Check required data quality rules

# Check for duplicate rows
for name, df in datasets.items():
    duplicates = df.duplicated().sum()
    print(f"{name}: {duplicates} duplicate rows")

# Check primary-key uniqueness
key_columns = {
    "customers": "customer_id",
    "products": "product_id",
    "suppliers": "supplier_id",
    "sales": "order_id",
    "procurement": "po_id"
}

for name, key in key_columns.items():
    df = datasets[name]
    duplicate_ids = df[key].duplicated().sum()
    print(f"{name}: {duplicate_ids} duplicate IDs")

# LOAD: Save transformed datasets

for name, df in datasets.items():
    output_file = processed_path / f"{name}.csv"
    df.to_csv(output_file, index=False)
    print(f"{name}: saved to {output_file}")

print("ETL pipeline completed successfully!")
