-- 1. City-Level Fare and Trip Summary Report
SELECT
    dc.city_name,
    COUNT(ft.trip_id) AS total_trips,
    ROUND(
        SUM(ft.fare_amount) / SUM(ft.distance_travelled_km),
        2
    ) AS avg_fare_per_km,
    ROUND(AVG(ft.fare_amount), 2) AS avg_fare_per_trip,
    ROUND(
        COUNT(ft.trip_id) * 100.0 / (
            SELECT
                COUNT(ft2.trip_id)
            FROM
                trips_db.fact_trips ft2
        ),
        2
    ) AS percentage_contribution_to_total_trips
FROM
    trips_db.dim_city dc
    JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
GROUP BY
    dc.city_name
ORDER BY
    total_trips DESC;

-- 2. MonthIy City-Level Trips Target Performance Report
SELECT
    dc.city_name,
    dd.month_name,
    COUNT(ft.trip_id) AS actual_trips,
    mt.total_target_trips AS target_trips,
    CASE
        WHEN COUNT(ft.trip_id) > mt.total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,
    ROUND(
        (COUNT(ft.trip_id) - mt.total_target_trips) * 100.0 / mt.total_target_trips,
        2
    ) AS percentage_difference
FROM
    trips_db.dim_city dc
    JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
    JOIN trips_db.dim_date dd ON ft.date = dd.date
    JOIN targets_db.monthly_target_trips mt ON dc.city_id = mt.city_id
    AND dd.start_of_month = mt.month
GROUP BY
    dc.city_name,
    dd.month_name,
    mt.total_target_trips
ORDER BY
    dc.city_name,
    dd.month_name;

-- 3. City-Level Repeat Passenger Trip Frequency Report
SELECT
    dc.city_name,
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '2-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "2-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '3-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "3-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '4-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "4-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '5-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "5-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '6-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "6-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '7-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "7-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '8-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "8-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '9-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "9-Trips",
    ROUND(
        SUM(
            CASE
                WHEN drtd.trip_count = '10-Trips' THEN drtd.repeat_passenger_count
                ELSE 0
            END
        ) * 100.0 / SUM(drtd.repeat_passenger_count),
        2
    ) AS "10-Trips"
FROM
    trips_db.dim_city dc
    JOIN trips_db.dim_repeat_trip_distribution drtd ON dc.city_id = drtd.city_id
GROUP BY
    dc.city_name
ORDER BY
    dc.city_name;

-- 4. Identify Cities with Highest and Lowest Total New Passengers
(
    SELECT
        dc.city_name,
        COUNT(
            CASE
                WHEN ft.passenger_type = 'new' THEN 1
            END
        ) AS total_new_passengers,
        'Top 3' AS city_category
    FROM
        trips_db.dim_city dc
        JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        total_new_passengers DESC
    LIMIT
        3
)
UNION ALL
(
    SELECT
        dc.city_name,
        COUNT(
            CASE
                WHEN ft.passenger_type = 'new' THEN 1
            END
        ) AS total_new_passengers,
        'Bottom 3' AS city_category
    FROM
        trips_db.dim_city dc
        JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
    GROUP BY
        dc.city_name
    ORDER BY
        total_new_passengers ASC
    LIMIT
        3
)
ORDER BY
    total_new_passengers DESC;

-- 5. Identify Month with Highest Revenue for Each City
WITH
    monthly_revenue AS (
        SELECT
            ft.city_id,
            dd.month_name,
            SUM(ft.fare_amount) AS revenue,
            SUM(SUM(ft.fare_amount)) OVER (
                PARTITION BY
                    ft.city_id
            ) AS total_city_revenue,
            ROW_NUMBER() OVER (
                PARTITION BY
                    ft.city_id
                ORDER BY
                    SUM(ft.fare_amount) DESC
            ) AS revenue_rank
        FROM
            trips_db.fact_trips ft
            JOIN trips_db.dim_date dd ON ft.date = dd.date
        GROUP BY
            ft.city_id,
            dd.month_name
    )
SELECT
    dc.city_name,
    mr.month_name AS highest_revenue_month,
    mr.revenue,
    ROUND(mr.revenue * 100.0 / mr.total_city_revenue, 2) AS percentage_contribution
FROM
    monthly_revenue mr
    JOIN trips_db.dim_city dc ON mr.city_id = dc.city_id
WHERE
    mr.revenue_rank = 1
ORDER BY
    dc.city_name;

-- 6. Repeat Passenger Rate Analysis (Monthly and City-wide Repeat Passenger Rate)
SELECT
    dc.city_name,
    dd.month_name AS month,
    COUNT(ft.trip_id) AS total_passengers,
    COUNT(
        CASE
            WHEN ft.passenger_type = 'repeated' THEN 1
        END
    ) AS repeat_passengers,
    ROUND(
        COUNT(
            CASE
                WHEN ft.passenger_type = 'repeated' THEN 1
            END
        ) * 100.0 / COUNT(ft.trip_id),
        2
    ) AS monthly_repeat_passenger_rate,
    ROUND(
        (
            SELECT
                COUNT(
                    CASE
                        WHEN ft2.passenger_type = 'repeated' THEN 1
                    END
                )
            FROM
                trips_db.fact_trips ft2
            WHERE
                ft2.city_id = dc.city_id
        ) * 100.0 / (
            SELECT
                COUNT(ft3.trip_id)
            FROM
                trips_db.fact_trips ft3
            WHERE
                ft3.city_id = dc.city_id
        ),
        2
    ) AS city_repeat_passenger_rate
FROM
    trips_db.dim_city dc
    JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
    JOIN trips_db.dim_date dd ON ft.date = dd.date
GROUP BY
    dc.city_name,
    dd.month_name,
    dc.city_id
ORDER BY
    dc.city_name,
    dd.month_name;




SELECT
    dc.city_name,
    dd.month_name AS month,
    COUNT(ft.trip_id) AS total_passengers,
    COUNT(CASE WHEN ft.passenger_type = 'repeated' THEN 1 END) AS repeat_passengers,
    -- Calculate Monthly Repeat Passenger Rate (RPR)
    ROUND(
        COUNT(CASE WHEN ft.passenger_type = 'repeated' THEN 1 END) * 100.0 /
        COUNT(ft.trip_id),
        2
    ) AS monthly_repeat_passenger_rate,
    -- Calculate Total Repeat Passenger Rate (RPR) for the City
    ROUND(
        SUM(COUNT(CASE WHEN ft.passenger_type = 'repeated' THEN 1 END)) OVER (PARTITION BY dc.city_name) * 100.0 /
        SUM(COUNT(ft.trip_id)) OVER (PARTITION BY dc.city_name),
        2
    ) AS city_repeat_passenger_rate
FROM
    trips_db.dim_city dc
    JOIN trips_db.fact_trips ft ON dc.city_id = ft.city_id
    JOIN trips_db.dim_date dd ON ft.date = dd.date
GROUP BY
    dc.city_name,
    dd.month_name
ORDER BY
    dc.city_name,
    dd.month_name;















