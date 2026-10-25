use supply_chain_intelligence;

## Which products have the highest demand?

-- Q1: Top products by total quantity ordered

SELECT
    p.product_id,
    p.SKU,
    p.product_name,
    p.category,
    SUM(s.order_quantity) AS total_quantity,
    COUNT(s.order_id) AS total_orders
FROM products AS p
JOIN sales AS s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.SKU,
    p.product_name,
    p.category
ORDER BY
    total_quantity DESC;

## Which products have the highest demand and how much are they worth?

-- Q2: High-demand products and their business value

SELECT
    p.product_id,
    p.SKU,
    p.product_name,
    p.category,
    SUM(s.order_quantity) AS total_quantity,
    COUNT(s.order_id) AS total_orders,
    ROUND(SUM(s.order_total), 2) AS total_order_value
FROM products AS p
JOIN sales AS s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.SKU,
    p.product_name,
    p.category
ORDER BY
    total_quantity DESC,
    total_order_value DESC;



## Which products have the highest demand relative to their category?

-- Q3: Products with highest demand within their category

WITH product_demand AS (
    SELECT
        p.product_id,
        p.SKU,
        p.product_name,
        p.category,
        SUM(s.order_quantity) AS total_quantity
    FROM products AS p
    JOIN sales AS s
        ON p.product_id = s.product_id
    GROUP BY
        p.product_id,
        p.SKU,
        p.product_name,
        p.category
),

category_demand AS (
    SELECT
        category,
        SUM(total_quantity) AS category_total_quantity
    FROM product_demand
    GROUP BY category
)

SELECT
    pd.product_id,
    pd.SKU,
    pd.product_name,
    pd.category,
    pd.total_quantity,
    cd.category_total_quantity,
    ROUND(
        100.0 * pd.total_quantity / cd.category_total_quantity,
        2
    ) AS category_demand_share_pct
FROM product_demand AS pd
JOIN category_demand AS cd
    ON pd.category = cd.category
ORDER BY
    category_demand_share_pct DESC;




























































































































