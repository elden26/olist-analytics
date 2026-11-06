-- ============================================================
-- OLIST: АНАЛИЗ СВОЕВРЕМЕННОСТИ ДОСТАВКИ
-- Источник данных: mart.csv
--
-- Направления исследования:
-- 1. Динамика опозданий во времени
-- 2. География опозданий по штатам покупателей
-- 3. Сравнение показателей продавцов
-- 4. Анализ типа маршрута доставки
--
-- Единицы анализа:
-- Заказ              — временной и географический анализ
-- Заказ — продавец   — анализ продавцов и маршрутов
-- ============================================================

-- 1. ВРЕМЕННАЯ ДИНАМИКА ОПОЗДАНИЙ
WITH unique_orders AS (
    SELECT DISTINCT
        order_id,
        order_month,
        is_late,
        delay_days
    FROM public.mart
)

SELECT
    order_month,
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late IS NOT NULL
    ) AS delivered_orders,

    -- Количество опоздавших заказов
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late = TRUE
    ) AS late_orders,

    -- Доля опоздавших заказов, %
    ROUND(
        COUNT(DISTINCT order_id) FILTER (
            WHERE is_late = TRUE
        ) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT order_id) FILTER (
                WHERE is_late IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_percentage,

    -- Средняя продолжительность опоздания,
    -- рассчитанная только для опоздавших заказов
    ROUND(
        AVG(delay_days) FILTER (
            WHERE is_late = TRUE
        ),
        2
    ) AS avg_delay_days

FROM unique_orders

GROUP BY order_month
ORDER BY order_month;

-- 2. ГЕОГРАФИЯ ОПОЗДАНИЙ ПО ШТАТАМ ПОКУПАТЕЛЕЙ
WITH unique_orders AS (
    SELECT DISTINCT
        order_id,
        customer_state,
        is_late,
        delay_days
    FROM public.mart
)

SELECT
    customer_state,

    -- Количество заказов с известным результатом доставки
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late IS NOT NULL
    ) AS delivered_orders,

    -- Количество опоздавших заказов
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late = TRUE
    ) AS late_orders,

    -- Доля опозданий, %
    ROUND(
        COUNT(DISTINCT order_id) FILTER (
            WHERE is_late = TRUE
        ) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT order_id) FILTER (
                WHERE is_late IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_percentage,

    -- Средняя продолжительность опоздания
    ROUND(
        AVG(delay_days) FILTER (
            WHERE is_late = TRUE
        ),
        2
    ) AS avg_delay_days

FROM unique_orders

WHERE customer_state IS NOT NULL

GROUP BY customer_state

ORDER BY late_delivery_percentage DESC;

-- 3. АНАЛИЗ ПОКАЗАТЕЛЕЙ ПРОДАВЦОВ
SELECT
    seller_id,
    seller_city,
    seller_state,

    -- Количество заказов продавца
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late IS NOT NULL
    ) AS delivered_orders,

    -- Количество опоздавших заказов
    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late = TRUE
    ) AS late_orders,

    -- Доля опозданий, %
    ROUND(
        COUNT(DISTINCT order_id) FILTER (
            WHERE is_late = TRUE
        ) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT order_id) FILTER (
                WHERE is_late IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_percentage,

    -- Средняя продолжительность опоздания
    ROUND(
        AVG(delay_days) FILTER (
            WHERE is_late = TRUE
        ),
        2
    ) AS avg_delay_days

FROM public.mart

GROUP BY
    seller_id,
    seller_city,
    seller_state

HAVING COUNT(DISTINCT order_id) FILTER (
    WHERE is_late IS NOT NULL
) >= 30

-- Сначала показываем продавцов с наибольшей
-- долей опоздавших заказов
ORDER BY
    late_delivery_percentage DESC,
    delivered_orders DESC;
-- 3.1. ПРОДАВЦЫ С НАИБОЛЬШИМ АБСОЛЮТНЫМ КОЛИЧЕСТВОМ ОПОЗДАНИЙ
SELECT
    seller_id,
    seller_city,
    seller_state,

    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late IS NOT NULL
    ) AS delivered_orders,

    COUNT(DISTINCT order_id) FILTER (
        WHERE is_late = TRUE
    ) AS late_orders,

    ROUND(
        COUNT(DISTINCT order_id) FILTER (
            WHERE is_late = TRUE
        ) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT order_id) FILTER (
                WHERE is_late IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_percentage

FROM public.mart

GROUP BY
    seller_id,
    seller_city,
    seller_state

HAVING COUNT(DISTINCT order_id) FILTER (
    WHERE is_late IS NOT NULL
) >= 30

-- Сортировка по абсолютному количеству опозданий
ORDER BY late_orders DESC;

-- 4. АНАЛИЗ ТИПА МАРШРУТА ДОСТАВКИ
SELECT
    route_type,

    -- Количество пар «заказ — продавец»
    -- с известным результатом доставки
    COUNT(*) FILTER (
        WHERE is_late IS NOT NULL
    ) AS order_seller_pairs,

    -- Количество опоздавших пар
    COUNT(*) FILTER (
        WHERE is_late = TRUE
    ) AS late_pairs,

    -- Доля опозданий, %
    ROUND(
        COUNT(*) FILTER (
            WHERE is_late = TRUE
        ) * 100.0
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE is_late IS NOT NULL
            ),
            0
        ),
        2
    ) AS late_delivery_percentage,

    -- Средняя продолжительность опоздания
    ROUND(
        AVG(delay_days) FILTER (
            WHERE is_late = TRUE
        ),
        2
    ) AS avg_delay_days

FROM public.mart

WHERE route_type IN ('same_state', 'different_state')

GROUP BY route_type

ORDER BY late_delivery_percentage DESC;



