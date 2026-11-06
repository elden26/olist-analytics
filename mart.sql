CREATE TABLE public.mart AS

WITH order_seller_pairs AS (
    SELECT DISTINCT
        order_id,
        seller_id
    FROM order_items
),

base_orders AS (
    SELECT
        order_id,
        customer_id,
        order_status,
        NULLIF(order_purchase_timestamp, '')::timestamp
            AS purchase_timestamp,
        NULLIF(order_delivered_customer_date, '')::timestamp
            AS delivered_timestamp,
        NULLIF(order_estimated_delivery_date, '')::timestamp
            AS estimated_timestamp
    FROM orders
)

SELECT
    o.order_id,
    p.seller_id,
    o.customer_id,

    o.order_status,
    o.purchase_timestamp,
    o.purchase_timestamp::date AS purchase_date,
    DATE_TRUNC('month', o.purchase_timestamp)::date AS order_month,

    c.customer_city,
    c.customer_state,

    s.seller_city,
    s.seller_state,

    CASE
        WHEN c.customer_state IS NULL
          OR s.seller_state IS NULL THEN 'unknown'
        WHEN c.customer_state = s.seller_state THEN 'same_state'
        ELSE 'different_state'
    END AS route_type,

    o.delivered_timestamp,
    o.estimated_timestamp,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.delivered_timestamp IS NOT NULL
         AND o.estimated_timestamp IS NOT NULL
        THEN o.delivered_timestamp > o.estimated_timestamp
        ELSE NULL
    END AS is_late,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.delivered_timestamp IS NOT NULL
         AND o.estimated_timestamp IS NOT NULL
         AND o.delivered_timestamp > o.estimated_timestamp
        THEN ROUND(
            (
                EXTRACT(EPOCH FROM (
                    o.delivered_timestamp - o.estimated_timestamp
                )) / 86400
            )::numeric,
            2
        )
        ELSE NULL
    END AS delay_days

FROM base_orders o

LEFT JOIN order_seller_pairs p
    ON o.order_id = p.order_id

LEFT JOIN customers c
    ON o.customer_id = c.customer_id

LEFT JOIN sellers s
    ON p.seller_id = s.seller_id;
