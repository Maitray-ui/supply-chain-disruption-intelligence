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

## Count total eligible orders per supplier

SELECT
    supplier_id,
    COUNT(*) AS eligible_orders
FROM procurement
WHERE delivery_date_actual IS NOT NULL
GROUP BY supplier_id
ORDER BY eligible_orders DESC;

## Calculate late-delivery performance

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS eligible_orders,
    SUM(
        CASE
            WHEN p.delivery_date_actual > p.delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_pct
FROM procurement AS p
JOIN suppliers AS s
    ON p.supplier_id = s.supplier_id
WHERE p.delivery_date_actual IS NOT NULL
GROUP BY s.supplier_id, s.supplier_name
ORDER BY late_delivery_pct DESC;



SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(p.delivery_date_actual) AS eligible_orders,
    SUM(
        CASE
            WHEN p.delivery_date_actual > p.delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(p.delivery_date_actual),
        2
    ) AS late_delivery_rate_pct
FROM suppliers AS s
JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
HAVING COUNT(p.delivery_date_actual) > 0
ORDER BY late_orders DESC
limit 10;

select 
po_id,
supplier_id,
delivery_date_planned,
delivery_date_actual,
datediff(delivery_date_actual,delivery_date_planned) as days_late
from procurement;
 
 ## finish supplier delay severity
 
 SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS late_orders,
    SUM(
        DATEDIFF(
            p.delivery_date_actual,
            p.delivery_date_planned
        )
    ) AS total_delay_days,
    ROUND(
        AVG(
            DATEDIFF(
                p.delivery_date_actual,
                p.delivery_date_planned
            )
        ),
        2
    ) AS avg_days_late
FROM procurement AS p
JOIN suppliers AS s
    ON p.supplier_id = s.supplier_id
WHERE p.delivery_date_actual > p.delivery_date_planned
GROUP BY
    s.supplier_id,
    s.supplier_name
ORDER BY total_delay_days DESC
LIMIT 10;




SELECT
    s.supplier_id,
    s.supplier_name,
    s.country,
    s.region,
    s.certification_level,
    s.preferred_supplier_flag,
    s.on_time_delivery_rate AS reported_on_time_rate,
    COUNT(p.po_id) AS total_procurement_orders,
    COUNT(p.delivery_date_actual) AS eligible_orders,
    SUM(
        CASE
            WHEN p.delivery_date_actual > p.delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0),
        2
    ) AS observed_late_rate_pct,
    ROUND(
        SUM(p.total_cost),
        2
    ) AS total_procurement_cost
FROM suppliers AS s
LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name,
    s.country,
    s.region,
    s.certification_level,
    s.preferred_supplier_flag,
    s.on_time_delivery_rate
ORDER BY observed_late_rate_pct DESC;

## Does supplier region affect delivery reliability?

SELECT
    s.region,
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
    ) AS late_rate_pct,
    ROUND(SUM(p.total_cost), 2) AS total_procurement_cost
FROM suppliers AS s
LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY s.region
ORDER BY late_rate_pct DESC;

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


## Do preferred suppliers perform better?
## Business question: Are suppliers marked as preferred actually more reliable?

SELECT
    COALESCE(s.preferred_supplier_flag, 'Unknown') AS preferred_status,
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
GROUP BY COALESCE(s.preferred_supplier_flag, 'Unknown')
ORDER BY late_rate_pct DESC;

## Country-level performance 
## Are certain supplier countries associated with higher delivery risk or greater procurement exposure?

SELECT
    s.country,
    COUNT(DISTINCT s.supplier_id) AS supplier_count,
    COUNT(p.po_id) AS total_orders,
    COUNT(p.delivery_date_actual) AS eligible_orders,

    SUM(
        CASE
            WHEN p.delivery_date_actual > p.delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0),
        2
    ) AS late_rate_pct,

    ROUND(SUM(p.total_cost), 2) AS total_procurement_cost

FROM suppliers AS s

LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id

GROUP BY s.country

ORDER BY late_rate_pct DESC;



## How has supplier delivery performance changed over time?

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN delivery_date_actual > delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / COUNT(delivery_date_actual),
        2
    ) AS late_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN DATEDIFF(
                    delivery_date_actual,
                    delivery_date_planned
                )
            END
        ),
        2
    ) AS avg_days_late,

    ROUND(SUM(total_cost), 2) AS procurement_cost

FROM procurement

GROUP BY DATE_FORMAT(order_date, '%Y-%m')

ORDER BY order_month;

## Are we financially dependent on a small number of suppliers?

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(p.po_id) AS total_orders,
    ROUND(SUM(p.total_cost), 2) AS total_procurement_cost,
    ROUND(AVG(p.unit_cost), 2) AS avg_unit_cost
FROM suppliers AS s
JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
ORDER BY total_procurement_cost DESC;

## Preferred versus non-preferred supplier reliability

SELECT
    COALESCE(s.preferred_supplier_flag, 'Unknown') AS preferred_status,
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
GROUP BY COALESCE(s.preferred_supplier_flag, 'Unknown')
ORDER BY late_rate_pct DESC;

## Which supplier countries have the greatest delivery risk?

SELECT
    s.country,
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
    ) AS late_rate_pct,
    ROUND(SUM(p.total_cost), 2) AS total_procurement_cost
FROM suppliers AS s
LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY s.country
ORDER BY late_rate_pct DESC;

## Are procurement delays getting worse over time?

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(*) AS total_orders,
    COUNT(delivery_date_actual) AS eligible_orders,
    SUM(
        CASE
            WHEN delivery_date_actual > delivery_date_planned
            THEN 1 ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(delivery_date_actual), 0),
        2
    ) AS late_rate_pct,
    ROUND(SUM(total_cost), 2) AS procurement_spend
FROM procurement
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;

## Compare delivery performance by year

SELECT
    YEAR(order_date) AS order_year,
    COUNT(*) AS total_orders,
    COUNT(delivery_date_actual) AS eligible_orders,
    SUM(
        CASE
            WHEN delivery_date_actual > delivery_date_planned
            THEN 1 ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(delivery_date_actual), 0),
        2
    ) AS late_rate_pct,
    ROUND(SUM(total_cost), 2) AS procurement_spend,
    ROUND(AVG(order_quantity), 2) AS avg_order_quantity
FROM procurement
GROUP BY YEAR(order_date)
ORDER BY order_year;

## Supplier share of total procurement spend

WITH supplier_spend AS (
    SELECT
        s.supplier_id,
        s.supplier_name,
        COUNT(p.po_id) AS total_orders,
        SUM(p.total_cost) AS total_spend
    FROM suppliers s
    JOIN procurement p
        ON s.supplier_id = p.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
)
SELECT
    supplier_id,
    supplier_name,
    total_orders,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(
        100.0 * total_spend /
        SUM(total_spend) OVER (),
        2
    ) AS spend_share_pct,
    ROUND(
        SUM(total_spend) OVER (
            ORDER BY total_spend DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 /
        SUM(total_spend) OVER (),
        2
    ) AS cumulative_spend_share_pct
FROM supplier_spend
ORDER BY total_spend DESC;

## Compare average unit cost by supplier
## Are we paying different prices to different suppliers?

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(p.po_id) AS total_orders,
    SUM(p.order_quantity) AS total_quantity,
    ROUND(AVG(p.unit_cost), 2) AS avg_unit_cost,
    ROUND(
        SUM(p.total_cost) / NULLIF(SUM(p.order_quantity), 0),
        2
    ) AS weighted_avg_unit_cost,
    ROUND(SUM(p.total_cost), 2) AS total_spend
FROM suppliers s
JOIN procurement p
    ON s.supplier_id = p.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
HAVING COUNT(p.po_id) >= 10
ORDER BY weighted_avg_unit_cost DESC;



## Does order size relate to delivery delays?
## Compare late-delivery rates by order-quantity band

WITH order_delivery AS (
    SELECT
        po_id,
        order_quantity,
        CASE
            WHEN order_quantity <= 5 THEN '1. Small (1-5)'
            WHEN order_quantity <= 10 THEN '2. Medium (6-10)'
            WHEN order_quantity <= 15 THEN '3. Large (11-15)'
            ELSE '4. Very Large (16+)'
        END AS quantity_band,
        CASE
            WHEN delivery_date_actual > delivery_date_planned
            THEN 1
            ELSE 0
        END AS is_late
    FROM procurement
    WHERE delivery_date_actual IS NOT NULL
)
SELECT
    quantity_band,
    COUNT(*) AS total_orders,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * AVG(is_late), 2) AS late_rate_pct,
    ROUND(AVG(order_quantity), 2) AS avg_order_quantity
FROM order_delivery
GROUP BY quantity_band
ORDER BY quantity_band;



## Procurement order cost distribution
## How much do we spend on each procurement order?

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(total_cost), 2) AS avg_order_cost,
    ROUND(MIN(total_cost), 2) AS min_order_cost,
    ROUND(MAX(total_cost), 2) AS max_order_cost,
    ROUND(AVG(order_quantity), 2) AS avg_quantity,
    ROUND(AVG(unit_cost), 2) AS avg_unit_cost,
    ROUND(SUM(total_cost), 2) AS total_procurement_spend
FROM procurement;



## Monthly procurement spending and delivery performance
## How does procurement spending change month by month?

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_cost), 2) AS monthly_spend,
    ROUND(AVG(total_cost), 2) AS avg_order_cost,
    ROUND(AVG(order_quantity), 2) AS avg_order_quantity,
    SUM(
        CASE
            WHEN delivery_date_actual > delivery_date_planned
            THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 * AVG(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS late_rate_pct
FROM procurement
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;























































