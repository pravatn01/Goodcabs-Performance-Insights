-- trips_db
SELECT
    *
FROM
    trips_db.dim_city;

SELECT
    *
FROM
    trips_db.dim_date;

SELECT
    *
FROM
    trips_db.dim_repeat_trip_distribution;

SELECT
    *
FROM
    trips_db.fact_passenger_summary;

SELECT
    *
FROM
    trips_db.fact_trips;

-- targets_db
SELECT
    *
FROM
    targets_db.city_target_passenger_rating;

SELECT
    *
FROM
    targets_db.monthly_target_new_passengers;

SELECT
    *
FROM
    targets_db.monthly_target_trips;

-- 1. Top and Bottom Performing Cities
(
    SELECT
        dc.city_name,
        COUNT(ft.trip_id) AS trip_count,
        'Top 3' AS category
    FROM
        trips_db.dim_city AS dc
        JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        trip_count DESC
    LIMIT
        3
)
UNION ALL
(
    SELECT
        dc.city_name,
        COUNT(ft.trip_id) AS trip_count,
        'Bottom 3' AS category
    FROM
        trips_db.dim_city AS dc
        JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        trip_count ASC
    LIMIT
        3
)
ORDER BY
    trip_count DESC;

-- 2. Average Fare per Trip by City
SELECT
    dc.city_name,
    ROUND(AVG(ft.fare_amount), 2) AS average_fare_per_trip,
    ROUND(AVG(ft.distance_travelled_km), 2) AS average_trip_distance
FROM
    trips_db.dim_city AS dc
    JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
GROUP BY
    dc.city_id
ORDER BY
    average_fare_per_trip DESC;

-- 3. Average Ratings by City and Passenger Type
WITH
    avg_ratings AS (
        SELECT
            dc.city_name,
            ft.passenger_type,
            ROUND(AVG(ft.passenger_rating), 2) AS avg_passenger_rating,
            ROUND(AVG(ft.driver_rating), 2) AS avg_driver_rating
        FROM
            trips_db.dim_city AS dc
            JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
        GROUP BY
            dc.city_name,
            ft.passenger_type
    )
SELECT
    ar.city_name,
    ar.passenger_type,
    ar.avg_passenger_rating,
    ar.avg_driver_rating,
    CASE
        WHEN ar.avg_passenger_rating = MAX(ar.avg_passenger_rating) OVER (PARTITION BY ar.passenger_type) THEN 'Highest Passenger Rating'
        WHEN ar.avg_passenger_rating = MIN(ar.avg_passenger_rating) OVER (PARTITION BY ar.passenger_type) THEN 'Lowest Passenger Rating'
        ELSE '-'
    END AS passenger_rating_category,
    CASE
        WHEN ar.avg_driver_rating = MAX(ar.avg_driver_rating) OVER (PARTITION BY ar.passenger_type) THEN 'Highest Driver Rating'
        WHEN ar.avg_driver_rating = MIN(ar.avg_driver_rating) OVER (PARTITION BY ar.passenger_type) THEN 'Lowest Driver Rating'
        ELSE '-'
    END AS driver_rating_category
FROM
    avg_ratings ar
ORDER BY
    ar.city_name,
    ar.passenger_type;


-- 4. Peak and Low Demand Months by City
WITH
    monthly_trip_counts AS (
        SELECT
            dc.city_name,
            dd.month_name,
            COUNT(ft.trip_id) AS trip_count
        FROM
            trips_db.dim_city AS dc
            JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
            JOIN trips_db.dim_date AS dd ON ft.date = dd.date
        GROUP BY
            dc.city_name,
            dd.month_name
    )
SELECT
    mtc.city_name,
    mtc.month_name,
    mtc.trip_count,
    CASE
        WHEN mtc.trip_count = MAX(mtc.trip_count) OVER (
            PARTITION BY
                mtc.city_name
        ) THEN 'Highest Trip Count'
        WHEN mtc.trip_count = MIN(mtc.trip_count) OVER (
            PARTITION BY
                mtc.city_name
        ) THEN 'Lowest Trip Count'
        ELSE '-'
    END AS trip_count_category
FROM
    monthly_trip_counts mtc
ORDER BY
    mtc.city_name,
    mtc.trip_count DESC;

-- 5. Weekend vs Weekday Trip Demand by City
SELECT
    dc.city_name,
    dd.day_type,
    COUNT(ft.trip_id) AS trip_count
FROM
    trips_db.dim_city AS dc
    JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
    JOIN trips_db.dim_date AS dd ON ft.date = dd.date
GROUP BY
    dc.city_name,
    dd.day_type
ORDER BY
    dc.city_name,
    dd.day_type ASC;

-- 6. Repeat Passenger Frequency and City Contribution Analysis
WITH
    tb_repeat AS (
        SELECT
            dc.city_name,
            SUM(drd.repeat_passenger_count) AS total_repeat_passenger_count
        FROM
            trips_db.dim_city AS dc
            JOIN trips_db.dim_repeat_trip_distribution AS drd ON dc.city_id = drd.city_id
        GROUP BY
            dc.city_name
    )
SELECT
    tb.city_name,
    tb.total_repeat_passenger_count,
    ROUND(
        tb.total_repeat_passenger_count / (
            SELECT
                SUM(total_repeat_passenger_count)
            FROM
                tb_repeat
        ) * 100,
        2
    ) AS city_contribution_percentage
FROM
    tb_repeat tb
ORDER BY
    tb.total_repeat_passenger_count DESC;

-- 7. Monthly Target Achievement Analysis for Key Metrics
SELECT
    dc.city_name,
    dd.start_of_month AS month,
    COUNT(ft.trip_id) AS actual_total_trips,
    MAX(mt.total_target_trips) AS target_total_trips,
    CASE
        WHEN COUNT(ft.trip_id) >= MAX(mt.total_target_trips) THEN 'Met/Exceeded'
        ELSE 'Missed'
    END AS total_trips_status,
    ROUND(
        (COUNT(ft.trip_id) - MAX(mt.total_target_trips)) / MAX(mt.total_target_trips) * 100,
        2
    ) AS total_trips_percentage_diff,
    COUNT(
        CASE
            WHEN ft.passenger_type = 'new' THEN 1
        END
    ) AS actual_new_passengers,
    MAX(mtn.target_new_passengers) AS target_new_passengers,
    CASE
        WHEN COUNT(
            CASE
                WHEN ft.passenger_type = 'new' THEN 1
            END
        ) >= MAX(mtn.target_new_passengers) THEN 'Met/Exceeded'
        ELSE 'Missed'
    END AS new_passengers_status,
    ROUND(
        (
            COUNT(
                CASE
                    WHEN ft.passenger_type = 'new' THEN 1
                END
            ) - MAX(mtn.target_new_passengers)
        ) / MAX(mtn.target_new_passengers) * 100,
        2
    ) AS new_passengers_percentage_diff,
    ROUND(AVG(ft.passenger_rating), 2) AS actual_avg_passenger_ratings,
    MAX(ctpr.target_avg_passenger_rating) AS target_avg_passenger_rating,
    CASE
        WHEN ROUND(AVG(ft.passenger_rating), 2) >= MAX(ctpr.target_avg_passenger_rating) THEN 'Met/Exceeded'
        ELSE 'Missed'
    END AS avg_passenger_ratings_status,
    ROUND(
        (
            ROUND(AVG(ft.passenger_rating), 2) - MAX(ctpr.target_avg_passenger_rating)
        ) / MAX(ctpr.target_avg_passenger_rating) * 100,
        2
    ) AS avg_passenger_ratings_percentage_diff
FROM
    trips_db.fact_trips AS ft
    JOIN trips_db.dim_city AS dc ON ft.city_id = dc.city_id
    JOIN trips_db.dim_date AS dd ON ft.date = dd.date
    JOIN targets_db.monthly_target_trips AS mt ON ft.city_id = mt.city_id
    AND dd.start_of_month = mt.month
    JOIN targets_db.monthly_target_new_passengers AS mtn ON ft.city_id = mtn.city_id
    AND dd.start_of_month = mtn.month
    JOIN targets_db.city_target_passenger_rating AS ctpr ON ft.city_id = ctpr.city_id
GROUP BY
    dc.city_name,
    dd.start_of_month
ORDER BY
    dc.city_name,
    dd.start_of_month;

-- 8. Highest and Lowest Repeat Passenger Rate (RPR%) by City and Month
-- By City
(
    SELECT
        dc.city_name,
        ROUND(
            COUNT(
                CASE
                    WHEN ft.passenger_type = 'repeated' THEN 1
                    ELSE NULL
                END
            ) * 100.0 / COUNT(ft.trip_id),
            2
        ) AS rpr_percentage,
        'Top 2' AS category
    FROM
        trips_db.dim_city AS dc
        JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        rpr_percentage DESC
    LIMIT
        2
)
UNION ALL
(
    SELECT
        dc.city_name,
        ROUND(
            COUNT(
                CASE
                    WHEN ft.passenger_type = 'repeated' THEN 1
                    ELSE NULL
                END
            ) * 100.0 / COUNT(ft.trip_id),
            2
        ) AS rpr_percentage,
        'Bottom 2' AS category
    FROM
        trips_db.dim_city AS dc
        JOIN trips_db.fact_trips AS ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        rpr_percentage ASC
    LIMIT
        2
)
ORDER BY
    rpr_percentage DESC;

-- By Month
(
    SELECT
        dd.month_name,
        ROUND(
            COUNT(
                CASE
                    WHEN ft.passenger_type = 'repeated' THEN 1
                    ELSE NULL
                END
            ) * 100.0 / COUNT(ft.trip_id),
            2
        ) AS rpr_percentage,
        'Highest RPR%' AS category
    FROM
        trips_db.fact_trips AS ft
        JOIN trips_db.dim_date AS dd ON ft.date = dd.date
    GROUP BY
        dd.month_name
    ORDER BY
        rpr_percentage DESC
    LIMIT
        1
)
UNION ALL
(
    SELECT
        dd.month_name,
        ROUND(
            COUNT(
                CASE
                    WHEN ft.passenger_type = 'repeated' THEN 1
                    ELSE NULL
                END
            ) * 100.0 / COUNT(ft.trip_id),
            2
        ) AS rpr_percentage,
        'Lowest RPR%' AS category
    FROM
        trips_db.fact_trips AS ft
        JOIN trips_db.dim_date AS dd ON ft.date = dd.date
    GROUP BY
        dd.month_name
    ORDER BY
        rpr_percentage ASC
    LIMIT
        1
)
ORDER BY
    rpr_percentage DESC;