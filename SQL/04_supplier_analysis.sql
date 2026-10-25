USE supply_chain_intelligence;

-- ============================================================
-- 04. SUPPLIER ANALYSIS
-- Supply Chain Disruption Intelligence
-- ============================================================


-- ============================================================
-- 1. SUPPLIER DELIVERY PERFORMANCE
-- ============================================================

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
GROUP BY
    s.supplier_id,
    s.supplier_name
ORDER BY late_delivery_pct DESC;


-- ============================================================
-- 2. SUPPLIER DELAY SEVERITY
-- ============================================================

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


-- ============================================================
-- 3. PREFERRED SUPPLIER PERFORMANCE
-- ============================================================

SELECT
    COALESCE(s.preferred_supplier_flag, 'Unknown') AS preferred_status,
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
    ) AS late_rate_pct
FROM suppliers AS s
LEFT JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY COALESCE(s.preferred_supplier_flag, 'Unknown')
ORDER BY late_rate_pct DESC;


-- ============================================================
-- 4. SUPPLIER PROFILE & OPERATIONAL PERFORMANCE
-- ============================================================

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


-- ============================================================
-- 5. SUPPLIER SPEND CONCENTRATION
-- ============================================================

WITH supplier_spend AS (
    SELECT
        s.supplier_id,
        s.supplier_name,
        SUM(p.total_cost) AS total_spend
    FROM suppliers AS s
    JOIN procurement AS p
        ON s.supplier_id = p.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
)

SELECT
    supplier_id,
    supplier_name,
    total_spend,
    ROUND(
        100.0 * total_spend / SUM(total_spend) OVER (),
        2
    ) AS spend_share_pct,
    ROUND(
        100.0 * SUM(total_spend) OVER (
            ORDER BY total_spend DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(total_spend) OVER (),
        2
    ) AS cumulative_spend_pct
FROM supplier_spend
ORDER BY total_spend DESC;


-- ============================================================
-- 6. SUPPLIER DEPENDENCY BY RAW MATERIAL
-- ============================================================

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(DISTINCT p.raw_material_id) AS unique_materials_supplied,
    SUM(p.order_quantity) AS total_quantity_supplied,
    ROUND(SUM(p.total_cost), 2) AS procurement_spend
FROM suppliers AS s
JOIN procurement AS p
    ON s.supplier_id = p.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
ORDER BY unique_materials_supplied DESC;


-- ============================================================
-- 7. SUPPLIER RISK DISTRIBUTION BY LATE-ORDER RATE
-- ============================================================

SELECT
    CASE
        WHEN late_order_pct >= 75 THEN '75-100%'
        WHEN late_order_pct >= 50 THEN '50-74.99%'
        WHEN late_order_pct >= 25 THEN '25-49.99%'
        ELSE '<25%'
    END AS late_order_rate_band,
    COUNT(*) AS supplier_count
FROM (
    SELECT
        supplier_id,
        100.0 * SUM(
            CASE
                WHEN delivery_date_actual > delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(delivery_date_actual), 0) AS late_order_pct
    FROM procurement
    GROUP BY supplier_id
) AS supplier_rates
WHERE late_order_pct IS NOT NULL
GROUP BY
    CASE
        WHEN late_order_pct >= 75 THEN '75-100%'
        WHEN late_order_pct >= 50 THEN '50-74.99%'
        WHEN late_order_pct >= 25 THEN '25-49.99%'
        ELSE '<25%'
    END
ORDER BY MIN(late_order_pct);


-- ============================================================
-- 8. SUPPLIER RISK SCORING
--
-- Risk score components:
--   Late-order risk       = 50%
--   Delay-severity risk   = 30%
--   Spend-exposure risk   = 20%
--
-- Risk categories:
--   >= 75 = Critical
--   >= 50 = High
--   >= 25 = Medium
--   < 25  = Low
-- ============================================================

WITH supplier_metrics AS (
    SELECT
        s.supplier_id,
        s.supplier_name,
        COUNT(p.po_id) AS total_orders,

        SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) AS late_orders,

        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0) AS late_order_pct,

        AVG(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN DATEDIFF(
                    p.delivery_date_actual,
                    p.delivery_date_planned
                )
            END
        ) AS avg_days_late,

        SUM(p.total_cost) AS procurement_spend
    FROM suppliers AS s
    LEFT JOIN procurement AS p
        ON s.supplier_id = p.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
),

normalized AS (
    SELECT
        *,
        late_order_pct / 100.0 AS late_order_risk,

        LEAST(
            COALESCE(avg_days_late, 0) / 5.0,
            1
        ) AS delay_severity_risk,

        procurement_spend /
        NULLIF(
            MAX(procurement_spend) OVER (),
            0
        ) AS spend_exposure_risk
    FROM supplier_metrics
)

SELECT
    supplier_id,
    supplier_name,
    total_orders,
    late_orders,
    ROUND(late_order_pct, 2) AS late_order_pct,
    ROUND(avg_days_late, 2) AS avg_days_late,
    ROUND(late_order_risk, 4) AS late_order_risk,
    ROUND(delay_severity_risk, 4) AS delay_severity_risk,
    ROUND(spend_exposure_risk, 4) AS spend_exposure_risk,

    ROUND(
        (
            late_order_risk * 50
        )
        +
        (
            delay_severity_risk * 30
        )
        +
        (
            spend_exposure_risk * 20
        ),
        2
    ) AS supplier_risk_score,

    CASE
        WHEN (
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20
        ) >= 75
            THEN 'Critical'

        WHEN (
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20
        ) >= 50
            THEN 'High'

        WHEN (
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20
        ) >= 25
            THEN 'Medium'

        ELSE 'Low'
    END AS risk_category

FROM normalized
ORDER BY supplier_risk_score DESC;


-- ============================================================
-- 9. SUPPLIER RISK DRIVER ANALYSIS
-- ============================================================

WITH supplier_metrics AS (
    SELECT
        s.supplier_id,
        s.supplier_name,

        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0) AS late_order_pct,

        AVG(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN DATEDIFF(
                    p.delivery_date_actual,
                    p.delivery_date_planned
                )
            END
        ) AS avg_days_late,

        SUM(p.total_cost) AS procurement_spend
    FROM suppliers AS s
    LEFT JOIN procurement AS p
        ON s.supplier_id = p.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
),

normalized AS (
    SELECT
        *,
        late_order_pct / 100.0 AS late_order_risk,

        LEAST(
            COALESCE(avg_days_late, 0) / 5.0,
            1
        ) AS delay_severity_risk,

        procurement_spend /
        NULLIF(
            MAX(procurement_spend) OVER (),
            0
        ) AS spend_exposure_risk
    FROM supplier_metrics
),

risk_scored AS (
    SELECT
        *,
        (
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20
        ) AS supplier_risk_score
    FROM normalized
)

SELECT
    supplier_id,
    supplier_name,
    ROUND(late_order_risk * 50, 2) AS reliability_component,
    ROUND(delay_severity_risk * 30, 2) AS delay_component,
    ROUND(spend_exposure_risk * 20, 2) AS financial_exposure_component,
    ROUND(supplier_risk_score, 2) AS supplier_risk_score,

    CASE
        WHEN late_order_risk >= 0.75
             AND delay_severity_risk >= 0.75
            THEN 'Multi-Factor Critical'

        WHEN late_order_risk >= 0.75
             AND delay_severity_risk >= 0.50
            THEN 'Reliability + Severe Delay'

        WHEN late_order_risk >= 0.75
             AND spend_exposure_risk >= 0.50
            THEN 'Reliability + Financial Exposure'

        WHEN delay_severity_risk >= 0.75
             AND spend_exposure_risk >= 0.50
            THEN 'Severe Delay + Financial Exposure'

        WHEN late_order_risk >= 0.75
            THEN 'Reliability Risk'

        WHEN delay_severity_risk >= 0.75
            THEN 'Delay Severity Risk'

        WHEN spend_exposure_risk >= 0.50
            THEN 'Financial Exposure Risk'

        ELSE 'Mixed / Moderate Risk'
    END AS primary_risk_driver

FROM risk_scored
ORDER BY supplier_risk_score DESC;


-- ============================================================
-- 10. SUPPLIER RISK × BUSINESS EXPOSURE
-- ============================================================

WITH supplier_metrics AS (
    SELECT
        s.supplier_id,
        s.supplier_name,

        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0) AS late_order_pct,

        AVG(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN DATEDIFF(
                    p.delivery_date_actual,
                    p.delivery_date_planned
                )
            END
        ) AS avg_days_late,

        SUM(p.total_cost) AS procurement_spend
    FROM suppliers AS s
    LEFT JOIN procurement AS p
        ON s.supplier_id = p.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
),

normalized AS (
    SELECT
        *,
        late_order_pct / 100.0 AS late_order_risk,

        LEAST(
            COALESCE(avg_days_late, 0) / 5.0,
            1
        ) AS delay_severity_risk,

        procurement_spend /
        NULLIF(
            MAX(procurement_spend) OVER (),
            0
        ) AS spend_exposure_risk
    FROM supplier_metrics
),

risk_scored AS (
    SELECT
        *,
        (
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20
        ) AS supplier_risk_score
    FROM normalized
)

SELECT
    supplier_id,
    supplier_name,
    ROUND(supplier_risk_score, 2) AS supplier_risk_score,
    ROUND(spend_exposure_risk * 100, 2) AS spend_exposure_pct,

    CASE
        WHEN supplier_risk_score >= 75
             AND spend_exposure_risk >= 0.50
            THEN 'Critical - High Risk + High Exposure'

        WHEN supplier_risk_score >= 50
             AND spend_exposure_risk < 0.50
            THEN 'High Risk - Lower Financial Exposure'

        WHEN supplier_risk_score >= 25
             AND spend_exposure_risk >= 0.50
            THEN 'Watch - Moderate Risk + High Exposure'

        WHEN supplier_risk_score >= 25
            THEN 'Moderate Risk - Lower Exposure'

        WHEN supplier_risk_score < 25
             AND spend_exposure_risk >= 0.50
            THEN 'Strategic Supplier - Low Operational Risk'

        ELSE 'Low Priority'
    END AS supplier_priority

FROM risk_scored
ORDER BY supplier_risk_score DESC;


-- ============================================================
-- 11. CREATE FINAL SUPPLIER RISK TABLE
-- This is the analytical dataset used downstream by Tableau.
-- ============================================================

DROP TABLE IF EXISTS supplier_risk;

CREATE TABLE supplier_risk AS

WITH supplier_metrics AS (
    SELECT
        s.supplier_id,
        s.supplier_name,

        COUNT(p.po_id) AS total_orders,

        SUM(p.order_quantity) AS total_quantity,

        SUM(p.total_cost) AS procurement_spend,

        100.0 * SUM(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(p.delivery_date_actual), 0) AS late_order_pct,

        AVG(
            CASE
                WHEN p.delivery_date_actual > p.delivery_date_planned
                THEN DATEDIFF(
                    p.delivery_date_actual,
                    p.delivery_date_planned
                )
            END
        ) AS avg_days_late

    FROM suppliers AS s
    LEFT JOIN procurement AS p
        ON s.supplier_id = p.supplier_id

    GROUP BY
        s.supplier_id,
        s.supplier_name
),

normalized AS (
    SELECT
        *,

        late_order_pct / 100.0 AS late_order_risk,

        LEAST(
            COALESCE(avg_days_late, 0) / 5.0,
            1
        ) AS delay_severity_risk,

        procurement_spend /
        NULLIF(
            MAX(procurement_spend) OVER (),
            0
        ) AS spend_exposure_risk

    FROM supplier_metrics
),

risk_scored AS (
    SELECT
        *,

        ROUND(
            late_order_risk * 50
            + delay_severity_risk * 30
            + spend_exposure_risk * 20,
            2
        ) AS supplier_risk_score

    FROM normalized
)

SELECT
    supplier_id,
    supplier_name,
    total_orders,
    total_quantity,
    procurement_spend,
    late_order_pct,
    avg_days_late,

    late_order_risk,
    delay_severity_risk,
    spend_exposure_risk,

    supplier_risk_score,

    CASE
        WHEN supplier_risk_score >= 75
            THEN 'Critical'

        WHEN supplier_risk_score >= 50
            THEN 'High'

        WHEN supplier_risk_score >= 25
            THEN 'Medium'

        ELSE 'Low'
    END AS risk_category

FROM risk_scored;


-- ============================================================
-- 12. SUPPLIER RISK DISTRIBUTION
-- ============================================================

SELECT
    risk_category,
    COUNT(*) AS supplier_count
FROM supplier_risk
GROUP BY risk_category
ORDER BY
    CASE risk_category
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END;


-- ============================================================
-- 13. TOP 10 HIGHEST-RISK SUPPLIERS
-- ============================================================

SELECT
    supplier_id,
    supplier_name,
    total_orders,
    total_quantity,
    procurement_spend,
    late_order_pct,
    avg_days_late,
    supplier_risk_score,
    risk_category
FROM supplier_risk
ORDER BY supplier_risk_score DESC
LIMIT 10;


-- ============================================================
-- 14. FINAL SUPPLIER RISK DETAIL
-- ============================================================

SELECT
    sr.supplier_id,
    sr.supplier_name,
    s.country,
    s.region,
    s.certification_level,
    s.preferred_supplier_flag,
    s.on_time_delivery_rate AS reported_on_time_rate,

    sr.total_orders,
    sr.total_quantity,
    sr.procurement_spend,
    sr.late_order_pct,
    sr.avg_days_late,

    sr.late_order_risk,
    sr.delay_severity_risk,
    sr.spend_exposure_risk,

    sr.supplier_risk_score,
    sr.risk_category

FROM supplier_risk AS sr
JOIN suppliers AS s
    ON sr.supplier_id = s.supplier_id

ORDER BY sr.supplier_risk_score DESC;
