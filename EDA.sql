-- =====================================================
-- EDA. ЭТАП 1. ОБЩИЙ ОБЗОР ДАННЫХ
-- =====================================================


-- 1. Количество записей в каждой таблице
-- Цель: определить объём данных и количество записей
-- в каждой из семи таблиц.

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


-- =====================================================
-- 2. Временной диапазон заказов
-- Цель: определить дату первого и последнего заказа,
-- а также общее количество заказов за исследуемый период.

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,
    COUNT(*) AS total_orders
FROM orders;


-- =====================================================
-- 3. Распределение заказов по статусам
-- Цель: определить количество и долю заказов
-- с каждым статусом относительно общего числа заказов.

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





-- =====================================================
-- EDA. ЭТАП 2. ВРЕМЕННОЙ АНАЛИЗ
-- =====================================================


-- 4. Динамика заказов по месяцам
-- Преобразуем текстовую дату в timestamp непосредственно в запросе.

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
-- Цель: исследовать изменение структуры заказов
-- и доли каждого статуса во времени.


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
-- пустые стоки в этой таблице заменили на нули так как ну, не сделали этого ранее а надо было
--Здесь мы:
--    Оставляем только доставленные заказы.
--    Сравниваем фактическую дату доставки с ожидаемой.
--    Считаем долю заказов с опозданием.
--    Рассчитываем среднее количество дней опоздания среди опоздавших заказов.
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
--Или рост объёма заказов сопровождался ухудшением логистики?
--есть ли связь между динамикой объёма заказов и качеством доставки.
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
--или они распределены равномерно
--Для этого объединим orders и customers по customer_id, 
--а затем рассчитаем показатели по штатам покупателей.
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



--Теперь у нас есть три измерения:
--   время — месяцы;
--   география — штаты покупателей;
--   качество — опоздания.
--проверим зависит ли качество доставки от конкретного продавца
-- Для этого соединим orders и order_items, затем сгруппируем заказы по продавцам.
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
--Покажет количество продавцов, среднюю и медианную долю опозданий, а также диапазон значений.
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
--Здесь я увеличил минимальный объём до 100 заказов, чтобы уменьшить влияние маленьких выборок.
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