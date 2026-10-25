use supply_chain_intelligence;

CREATE TABLE sales (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    product_id VARCHAR(20),
    order_date DATE,
    order_status VARCHAR(30),
    order_quantity INT,
    unit_price DECIMAL(12,2),
    discount DECIMAL(5,4),
    shipping_mode VARCHAR(30),
    shipping_carrier VARCHAR(50),
    shipping_date_scheduled DATE,
    shipping_date_actual DATE,
    delivery_status VARCHAR(30),
    late_delivery_risk_flag BOOLEAN,
    vat_rate DECIMAL(5,4),
    cogs DECIMAL(12,2),
    unit_price_effective DECIMAL(12,2),
    order_total DECIMAL(12,2),
    vat_amount DECIMAL(12,2),
    profit_per_order DECIMAL(12,2)
);

describe sales;

select * from sales;

select count(*)
 from sales;
 
 CREATE TABLE procurement (
    po_id VARCHAR(20) PRIMARY KEY,
    supplier_id VARCHAR(20),
    raw_material_id VARCHAR(20),
    order_date DATE,
    order_quantity INT,
    unit_cost DECIMAL(12,2),
    delivery_date_planned DATE,
    delivery_date_actual DATE,
    total_cost DECIMAL(14,2)
);

describe procurement;

select * from procurement;


show tables;

## Verify the row counts

SELECT 'customers' AS table_name, COUNT(*) AS total_rows
FROM customers

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'suppliers', COUNT(*)
FROM suppliers

UNION ALL

SELECT 'sales', COUNT(*)
FROM sales

UNION ALL

SELECT 'procurement', COUNT(*)
FROM procurement;


describe sales;

describe procurement;
describe suppliers;

SELECT
    s.product_id,
    p.raw_material_id
FROM sales AS s
INNER JOIN procurement AS p
    ON s.product_id = p.raw_material_id
LIMIT 10;


SELECT
    COUNT(*) AS matching_row_pairs
FROM sales AS s
INNER JOIN procurement AS p
    ON s.product_id = p.raw_material_id;

## distinct IDs in each column.

SELECT
    'sales.product_id' AS source_column,
    COUNT(DISTINCT product_id) AS distinct_ids
FROM sales

UNION ALL

SELECT
    'procurement.raw_material_id',
    COUNT(DISTINCT raw_material_id)
FROM procurement;


## the actual product master

SELECT
    COUNT(DISTINCT s.product_id) AS sales_product_ids,
    COUNT(DISTINCT p.product_id) AS ids_found_in_product_master
FROM sales AS s
LEFT JOIN products AS p
    ON s.product_id = p.product_id;


## late procurement orders

select 
po_id,
supplier_id,
delivery_date_planned,
delivery_date_actual
from procurement
where delivery_date_actual > delivery_date_planned;

## Add supplier names

select 
s.supplier_name,
p.po_id,
p.delivery_date_planned,
p.delivery_date_actual
from procurement as p
join suppliers as s
on p.supplier_id = s.supplier_id
where delivery_date_actual > delivery_date_planned;

## Count the late procurement orders for each supplier.

SELECT
    supplier_id,
    COUNT(*) AS late_orders
FROM procurement
WHERE delivery_date_actual > delivery_date_planned
GROUP BY supplier_id
ORDER BY late_orders DESC;

## Add supplier names

SELECT
    s.supplier_name,
    COUNT(*) AS late_orders
FROM procurement AS p
JOIN suppliers AS s
    ON p.supplier_id = s.supplier_id
WHERE p.delivery_date_actual > p.delivery_date_planned
GROUP BY s.supplier_id, s.supplier_name
ORDER BY late_orders DESC;




## Does certification level relate to delivery reliability?

SELECT
    COALESCE(s.certification_level, 'Unknown') AS certification_level,
    COUNT(DISTINCT s.supplier_id) AS supplier_count,
    COUNT(p.po_id) AS total_orders,
    COUNT(p.delivery_date_actual) AS eligible_orders,
    SUM(
        CASE
            WHEN p.delivery_date_actual > p.delivery_date_planned
            THEN 1 ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0),
        2
    ) AS late_rate_pct
FROM suppliers AS s
LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY COALESCE(s.certification_level, 'Unknown')
ORDER BY late_rate_pct DESC;








































