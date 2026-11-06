-- =====================================================
-- EDA. ЭТАП 1. ОБЩИЙ ОБЗОР ДАННЫХ
-- =====================================================
--Количество записей в каждой таблице
SELECT 'customers' AS table_name, COUNT(*) AS rows_count
FROM customers

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM order_payments

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'product_category', COUNT(*)
FROM product_category

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers

ORDER BY table_name;

-- Временной диапазон заказов

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,
    COUNT(*) AS total_orders
FROM orders;

-- Распределение заказов по статусам
SELECT
    order_status,
    COUNT(*) AS orders_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY orders_count DESC;

--Динамика заказов по месяцам
SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp::timestamp
    )::date AS order_month,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
    ) AS canceled_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) * 100.0 / COUNT(*),
        2
    ) AS delivered_percentage

FROM orders

GROUP BY DATE_TRUNC(
    'month',
    order_purchase_timestamp::timestamp
)

ORDER BY order_month;

-- 5. Распределение заказов по статусам в разрезе месяцев
SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp::timestamp
    )::date AS order_month,

    order_status,

    COUNT(*) AS orders_count,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (
            PARTITION BY DATE_TRUNC(
                'month',
                order_purchase_timestamp::timestamp
            )
        ),
        2
    ) AS status_percentage

FROM orders

GROUP BY
    DATE_TRUNC(
        'month',
        order_purchase_timestamp::timestamp
    ),
    order_status

ORDER BY
    order_month,
    orders_count DESC;


--Насколько фактическая доставка соответствует обещанному сроку?
SELECT
    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE NULLIF(order_delivered_customer_date, '')::timestamp
            > NULLIF(order_estimated_delivery_date, '')::timestamp
    ) AS late_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE NULLIF(order_delivered_customer_date, '')::timestamp
                > NULLIF(order_estimated_delivery_date, '')::timestamp
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_percentage,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    NULLIF(order_delivered_customer_date, '')::timestamp
                    - NULLIF(order_estimated_delivery_date, '')::timestamp
                )
            ) / 86400.0
        ) FILTER (
            WHERE NULLIF(order_delivered_customer_date, '')::timestamp
                > NULLIF(order_estimated_delivery_date, '')::timestamp
        ),
        2
    ) AS avg_delay_days

FROM orders

WHERE order_status = 'delivered'
  AND NULLIF(order_delivered_customer_date, '') IS NOT NULL
  AND NULLIF(order_estimated_delivery_date, '') IS NOT NULL;

-- как изменилось качество доставки? Стало ли Olist доставлять лучше со временем? 
SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp::timestamp
    )::date AS order_month,

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::timestamp
            > order_estimated_delivery_date::timestamp
    ) AS late_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date::timestamp
                > order_estimated_delivery_date::timestamp
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_percentage,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date::timestamp
                    - order_estimated_delivery_date::timestamp
                )
            ) / 86400.0
        ) FILTER (
            WHERE order_delivered_customer_date::timestamp
                > order_estimated_delivery_date::timestamp
        ),
        2
    ) AS avg_delay_days

FROM orders

WHERE order_status = 'delivered'
  AND NULLIF(order_delivered_customer_date, '') IS NOT NULL
  AND NULLIF(order_estimated_delivery_date, '') IS NOT NULL

GROUP BY 1
ORDER BY 1;


--исследуем географию опозданий, где именно возникают проблемы: в отдельных штатах Бразилии 
SELECT
    c.customer_state,

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date::timestamp
            > o.order_estimated_delivery_date::timestamp
    ) AS late_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_percentage,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date::timestamp
                    - o.order_estimated_delivery_date::timestamp
                )
            ) / 86400.0
        ) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ),
        2
    ) AS avg_delay_days

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
  AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL

GROUP BY c.customer_state

ORDER BY late_delivery_percentage DESC;

--проверим зависит ли качество доставки от конкретного продавца
SELECT
    oi.seller_id,

    COUNT(DISTINCT o.order_id) AS delivered_orders,

    COUNT(DISTINCT o.order_id) FILTER (
        WHERE o.order_delivered_customer_date::timestamp
            > o.order_estimated_delivery_date::timestamp
    ) AS late_orders,

    ROUND(
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ) * 100.0
        / COUNT(DISTINCT o.order_id),
        2
    ) AS late_delivery_percentage

FROM orders o

JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'
  AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
  AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL

GROUP BY oi.seller_id

HAVING COUNT(DISTINCT o.order_id) >= 30

ORDER BY late_delivery_percentage DESC;

-- общее по продавцам
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ) AS late_orders
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
      AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT o.order_id) >= 30
),
rates AS (
    SELECT
        seller_id,
        delivered_orders,
        late_orders,
        late_orders * 100.0 / delivered_orders AS late_rate
    FROM seller_stats
)
SELECT
    COUNT(*) AS sellers_count,
    ROUND(AVG(late_rate), 2) AS avg_late_rate,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY late_rate)::numeric,
        2
    ) AS median_late_rate,
    ROUND(MIN(late_rate)::numeric, 2) AS min_late_rate,
    ROUND(MAX(late_rate)::numeric, 2) AS max_late_rate
FROM rates;

-- Продавцы с наибольшей долей опозданий
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ) AS late_orders
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
      AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL
    GROUP BY oi.seller_id
)
SELECT
    seller_id,
    delivered_orders,
    late_orders,
    ROUND(late_orders * 100.0 / delivered_orders, 2)
        AS late_delivery_percentage
FROM seller_stats
WHERE delivered_orders >= 100
ORDER BY late_delivery_percentage DESC
LIMIT 20;

--Продавцы с наибольшим количеством опозданий
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date::timestamp
                > o.order_estimated_delivery_date::timestamp
        ) AS late_orders
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
      AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL
    GROUP BY oi.seller_id
)
SELECT
    seller_id,
    delivered_orders,
    late_orders,
    ROUND(late_orders * 100.0 / delivered_orders, 2)
        AS late_delivery_percentage
FROM seller_stats
ORDER BY late_orders DESC
LIMIT 20;



--отличаются ли опоздания для заказов внутри одного штата и между разными штатами.
WITH order_seller AS (
    SELECT DISTINCT
        o.order_id,
        oi.seller_id,
        o.customer_id,
        o.order_delivered_customer_date::timestamp
            AS delivered_date,
        o.order_estimated_delivery_date::timestamp
            AS estimated_date
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND NULLIF(o.order_delivered_customer_date, '') IS NOT NULL
      AND NULLIF(o.order_estimated_delivery_date, '') IS NOT NULL
),
delivery_data AS (
    SELECT
        os.order_id,
        os.seller_id,
        CASE
            WHEN s.seller_state = c.customer_state
                THEN 'same_state'
            ELSE 'different_state'
        END AS route_type,
        CASE
            WHEN os.delivered_date > os.estimated_date
                THEN 1
            ELSE 0
        END AS is_late,
        EXTRACT(
            EPOCH FROM (os.delivered_date - os.estimated_date)
        ) / 86400.0 AS delay_days
    FROM order_seller os
    JOIN sellers s
        ON os.seller_id = s.seller_id
    JOIN customers c
        ON os.customer_id = c.customer_id
)
SELECT
    route_type,
    COUNT(*) AS order_seller_pairs,
    SUM(is_late) AS late_pairs,
    ROUND(AVG(is_late) * 100, 2) AS late_percentage,
    ROUND(
        AVG(delay_days) FILTER (WHERE is_late = 1)::numeric,
        2
    ) AS avg_delay_days
FROM delivery_data
GROUP BY route_type
ORDER BY route_type;
