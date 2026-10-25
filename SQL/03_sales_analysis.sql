use supply_chain_intelligence;


## What does order status tell us about sales performance?

SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct,
    ROUND(SUM(order_total), 2) AS total_order_value,
    ROUND(AVG(order_total), 2) AS avg_order_value,
    ROUND(SUM(profit_per_order), 2) AS total_recorded_profit,
    SUM(
        CASE
            WHEN shipping_date_actual IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS orders_with_actual_ship_date,
    SUM(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS late_shipments
FROM sales
GROUP BY order_status
ORDER BY total_orders DESC;

## Investigate shipping dates for pending and cancelled orders

-- Sales Analysis 2: Check shipping dates for non-completed orders

SELECT
    order_status,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN shipping_date_scheduled IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS orders_with_scheduled_ship_date,

    SUM(
        CASE
            WHEN shipping_date_actual IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS orders_with_actual_ship_date,

    SUM(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    SUM(
        CASE
            WHEN shipping_date_actual < shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS early_shipments,

    SUM(
        CASE
            WHEN shipping_date_actual = shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS on_schedule_shipments

FROM sales
GROUP BY order_status
ORDER BY total_orders DESC;


## What is the overall shipping delay?

-- Sales Analysis 3: Shipping delay severity by order status

SELECT
    order_status,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS late_shipment_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN DATEDIFF(
                    shipping_date_actual,
                    shipping_date_scheduled
                )
            END
        ),
        2
    ) AS avg_delay_days,

    MAX(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN DATEDIFF(
                shipping_date_actual,
                shipping_date_scheduled
            )
        END
    ) AS max_delay_days

FROM sales
GROUP BY order_status
ORDER BY total_orders DESC;

## Which shipping carriers have the highest late-shipment rates?

-- Sales Analysis 4: Shipping performance by carrier

SELECT
    shipping_carrier,
    COUNT(*) AS total_shipments,

    SUM(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN 1 ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS late_shipment_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN DATEDIFF(
                    shipping_date_actual,
                    shipping_date_scheduled
                )
            END
        ),
        2
    ) AS avg_delay_days

FROM sales
GROUP BY shipping_carrier
ORDER BY late_shipment_rate_pct DESC;

## Does shipping mode affect late-shipment rates?
## Are some shipping modes associated with more frequent late shipments?

-- Sales Analysis 5: Shipping performance by shipping mode

SELECT
    shipping_mode,
    COUNT(*) AS total_shipments,

    SUM(
        CASE
            WHEN shipping_date_actual > shipping_date_scheduled
            THEN 1
            ELSE 0
        END
    ) AS late_shipments,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS late_shipment_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN shipping_date_actual > shipping_date_scheduled
                THEN DATEDIFF(
                    shipping_date_actual,
                    shipping_date_scheduled
                )
            END
        ),
        2
    ) AS avg_delay_days

FROM sales
GROUP BY shipping_mode
ORDER BY late_shipment_rate_pct DESC;

## How have orders and sales value changed over time?
## Are order volume, recorded order value, and recorded profit changing over time?

-- Sales Analysis 6: Monthly sales and order trends

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,

    COUNT(*) AS total_orders,

    SUM(
        CASE WHEN order_status = 'Completed'
             THEN 1 ELSE 0
        END
    ) AS completed_orders,

    SUM(
        CASE WHEN order_status = 'Pending'
             THEN 1 ELSE 0
        END
    ) AS pending_orders,

    SUM(
        CASE WHEN order_status = 'Cancelled'
             THEN 1 ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(SUM(order_total), 2) AS recorded_order_value,

    ROUND(SUM(profit_per_order), 2) AS recorded_profit

FROM sales
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;


## Investigate cancellation rates

-- Sales Analysis 7: Monthly cancellation rate

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN order_status = 'Cancelled' THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN order_status = 'Cancelled' THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct

FROM sales
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY cancellation_rate_pct DESC;


## Which products had the most cancelled orders?
-- Sales Analysis 8: Cancellation patterns by product

SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled' THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled' THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct

FROM sales AS s
JOIN products AS p
    ON s.product_id = p.product_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'

GROUP BY
    p.product_id,
    p.product_name,
    p.category

HAVING COUNT(*) >= 5

ORDER BY
    cancelled_orders DESC,
    cancellation_rate_pct DESC;




## Are cancellations concentrated by product category?
## Is the April 2024 cancellation spike concentrated in a particular product category?

-- Sales Analysis 9: April 2024 cancellation rate by category

SELECT
    p.category,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(s.order_total),
        2
    ) AS recorded_order_value

FROM sales AS s
JOIN products AS p
    ON s.product_id = p.product_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'

GROUP BY
    p.category

ORDER BY
    cancellation_rate_pct DESC;


## Are cancellations related to shipping mode?

-- Sales Analysis 10: April 2024 cancellation rate by shipping mode

SELECT
    shipping_mode,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    SUM(
        CASE
            WHEN order_status = 'Cancelled'
            THEN order_total
            ELSE 0
        END
    ) AS cancelled_order_value

FROM sales

WHERE order_date >= '2024-04-01'
  AND order_date < '2024-05-01'

GROUP BY shipping_mode

ORDER BY cancellation_rate_pct DESC;


## Are cancellations related to shipping mode?


-- Sales Analysis 10: April 2024 cancellation rate by shipping mode

SELECT
    shipping_mode,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    SUM(
        CASE
            WHEN order_status = 'Cancelled'
            THEN order_total
            ELSE 0
        END
    ) AS cancelled_order_value

FROM sales

WHERE order_date >= '2024-04-01'
  AND order_date < '2024-05-01'

GROUP BY shipping_mode

ORDER BY cancellation_rate_pct DESC;


## Are Standard-shipping cancellations concentrated in a particular category?

-- Sales Analysis 11: Standard-shipping cancellations by category
-- April 2024

SELECT
    p.category,

    COUNT(*) AS standard_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN products AS p
    ON s.product_id = p.product_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'
  AND s.shipping_mode = 'Standard'

GROUP BY p.category

ORDER BY cancelled_orders DESC;

## Who are the customers behind these cancellations?
## Are April 2024 Standard-shipping cancellations concentrated among particular customers or customer segments?

-- Sales Analysis 12: April 2024 Standard-shipping cancellations by customer

SELECT
    c.customer_id,
    c.customer_name,
    c.industry,
    c.market_segment,
    c.country,

    COUNT(*) AS standard_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'
  AND s.shipping_mode = 'Standard'

GROUP BY
    c.customer_id,
    c.customer_name,
    c.industry,
    c.market_segment,
    c.country

HAVING COUNT(*) >= 2

ORDER BY
    cancelled_orders DESC,
    cancellation_rate_pct DESC;



## Are cancellations related to customer segment?
## Do B2B and B2C customers have different cancellation behavior?

-- Sales Analysis 13: Cancellation rate by customer market segment
-- April 2024

SELECT
    c.market_segment,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'

GROUP BY c.market_segment

ORDER BY cancellation_rate_pct DESC;

## Are cancellations concentrated by country?
## Is the April 2024 cancellation spike concentrated in particular customer countries?

-- Sales Analysis 14: April 2024 cancellation rate by customer country

SELECT
    c.country,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'

GROUP BY c.country

HAVING COUNT(*) >= 10

ORDER BY cancellation_rate_pct DESC;


## What is driving cancellations in France?
## Which product categories are responsible for France's April 2024 cancellations?

-- Sales Analysis 15: France cancellation rate by category
-- April 2024

SELECT
    p.category,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

JOIN products AS p
    ON s.product_id = p.product_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'
  AND c.country = 'France'

GROUP BY p.category

ORDER BY cancelled_orders DESC;

## Is France's cancellation problem connected to shipping mode?
## Which shipping modes have the highest cancellation rates for French customers?

-- Sales Analysis 16: France cancellation rate by shipping mode
-- April 2024

SELECT
    s.shipping_mode,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'
  AND c.country = 'France'

GROUP BY s.shipping_mode

ORDER BY cancellation_rate_pct DESC;

use supply_chain_intelligence;


## France × Shipping Mode × Category
## Which product categories are driving the high cancellation rate for French customers using Economy or Express shipping?

-- Sales Analysis 17: France cancellation drivers
-- Economy + Express shipping

SELECT
    p.category,
    s.shipping_mode,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

JOIN products AS p
    ON s.product_id = p.product_id

WHERE s.order_date >= '2024-04-01'
  AND s.order_date < '2024-05-01'
  AND c.country = 'France'
  AND s.shipping_mode IN ('Economy', 'Express')

GROUP BY
    p.category,
    s.shipping_mode

ORDER BY
    cancelled_orders DESC,
    cancellation_rate_pct DESC;

## Are cancellations associated with order value?
## Are higher-value orders more likely to be cancelled?

-- Sales Analysis 18: Cancellation rate by order value band

SELECT
    CASE
        WHEN order_total < 250 THEN '1. Low (<250)'
        WHEN order_total < 500 THEN '2. Medium (250-499)'
        WHEN order_total < 750 THEN '3. High (500-749)'
        ELSE '4. Very High (750+)'
    END AS order_value_band,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN order_status = 'Cancelled'
                THEN order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales

GROUP BY
    CASE
        WHEN order_total < 250 THEN '1. Low (<250)'
        WHEN order_total < 500 THEN '2. Medium (250-499)'
        WHEN order_total < 750 THEN '3. High (500-749)'
        ELSE '4. Very High (750+)'
    END

ORDER BY order_value_band;

## Are cancellations concentrated among certain products?
## Which products generate the most cancelled orders and cancelled revenue?

-- Sales Analysis 19: Product-level cancellation impact

SELECT
    p.product_id,
    p.product_name,
    p.category,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN products AS p
    ON s.product_id = p.product_id

GROUP BY
    p.product_id,
    p.product_name,
    p.category

HAVING COUNT(*) >= 20

ORDER BY
    cancelled_order_value DESC;

## Customer cancellation behavior
## Are certain customers repeatedly cancelling orders?

-- Sales Analysis 20: Customer-level cancellation behavior

SELECT
    c.customer_id,
    c.customer_name,
    c.industry,
    c.market_segment,
    c.country,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

GROUP BY
    c.customer_id,
    c.customer_name,
    c.industry,
    c.market_segment,
    c.country

HAVING COUNT(*) >= 10

ORDER BY
    cancelled_orders DESC,
    cancelled_order_value DESC;

## Which industries have the most cancellations?
## Are cancellations concentrated within specific customer industries?

-- Sales Analysis 21: Cancellation behavior by customer industry

SELECT
    c.industry,

    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN s.order_status = 'Cancelled'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_orders,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS cancellation_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN s.order_status = 'Cancelled'
                THEN s.order_total
                ELSE 0
            END
        ),
        2
    ) AS cancelled_order_value

FROM sales AS s

JOIN customers AS c
    ON s.customer_id = c.customer_id

GROUP BY
    c.industry

ORDER BY
    cancellation_rate_pct DESC;