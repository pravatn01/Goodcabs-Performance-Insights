--trips_db
use trips_db;
select *
from dim_city;
select *
from dim_date;
select *
from dim_repeat_trip_distribution;
select *
from fact_passenger_summary;
select *
from fact_trips;
-- targets_db
use targets_db;
select *
from city_target_passenger_rating;
select *
from monthly_target_new_passengers;
select *
from monthly_target_trips;
-- 1. Top and Bottom Performing Cities
(
    SELECT a.city_name,
        COUNT(b.trip_id) AS trip_count,
        'Top 3' AS category
    FROM dim_city AS a
        JOIN fact_trips AS b ON a.city_id = b.city_id
    GROUP BY a.city_name
    ORDER BY trip_count DESC
    LIMIT 3
)
UNION ALL
(
    SELECT a.city_name,
        COUNT(b.trip_id) AS trip_count,
        'Bottom 3' AS category
    FROM dim_city AS a
        JOIN fact_trips AS b ON a.city_id = b.city_id
    GROUP BY a.city_name
    ORDER BY trip_count ASC
    LIMIT 3
)
ORDER BY trip_count DESC;
-- 2. Average Fare per Trip by City
SELECT a.city_name,
    round(avg(b.fare_amount), 2) AS average_fare_per_trip,
    round(avg(distance_travelled_km), 2) AS average_trip_distance
FROM dim_city AS a
    JOIN fact_trips AS b ON a.city_id = b.city_id
GROUP BY a.city_id
ORDER BY average_fare_per_trip DESC;
-- 3. Average Ratings by City and Passenger Type
WITH avg_ratings AS (
    SELECT a.city_name,
        b.passenger_type,
        ROUND(AVG(b.passenger_rating), 2) AS avg_passenger_rating,
        ROUND(AVG(b.driver_rating), 2) AS avg_driver_rating
    FROM dim_city a
        JOIN fact_trips b ON a.city_id = b.city_id
    GROUP BY a.city_name,
        b.passenger_type
)
SELECT ar.city_name,
    ar.passenger_type,
    ar.avg_passenger_rating,
    ar.avg_driver_rating,
    CASE
        WHEN ar.avg_passenger_rating = MAX(ar.avg_passenger_rating) OVER () THEN 'Highest Passenger Rating'
        WHEN ar.avg_passenger_rating = MIN(ar.avg_passenger_rating) OVER () THEN 'Lowest Passenger Rating'
        ELSE '-'
    END AS passenger_rating_category,
    CASE
        WHEN ar.avg_driver_rating = MAX(ar.avg_driver_rating) OVER () THEN 'Highest Driver Rating'
        WHEN ar.avg_driver_rating = MIN(ar.avg_driver_rating) OVER () THEN 'Lowest Driver Rating'
        ELSE '-'
    END AS driver_rating_category
FROM avg_ratings ar
ORDER BY ar.city_name,
    ar.passenger_type;
-- 4. Peak and Low Demand Months by City
WITH monthly_trip_counts AS (
    SELECT a.city_name,
        c.month_name,
        COUNT(b.trip_id) AS trip_count
    FROM dim_city AS a
        JOIN fact_trips AS b ON a.city_id = b.city_id
        JOIN dim_date AS c ON b.date = c.date
    GROUP BY a.city_name,
        c.month_name
)
SELECT mtc.city_name,
    mtc.month_name,
    mtc.trip_count,
    CASE
        WHEN mtc.trip_count = MAX(mtc.trip_count) OVER (PARTITION BY mtc.city_name) THEN 'Highest Trip Count'
        WHEN mtc.trip_count = MIN(mtc.trip_count) OVER (PARTITION BY mtc.city_name) THEN 'Lowest Trip Count'
        ELSE '-'
    END AS trip_count_category
FROM monthly_trip_counts mtc
ORDER BY mtc.city_name,
    mtc.trip_count DESC;
-- 5. Weekend vs Weekday Trip Demand by City
SELECT a.city_name,
    c.day_type,
    COUNT(b.trip_id) AS trip_count
FROM dim_city AS a
    JOIN fact_trips AS b ON a.city_id = b.city_id
    JOIN dim_date AS c ON b.date = c.date
GROUP BY a.city_name,
    c.day_type
ORDER BY dc.city_name,
    dd.day_type;
-- 6. Repeat Passenger Frequency and City Contribution Analysis
WITH tb_repeat AS (
    SELECT a.city_name,
        SUM(b.repeat_passenger_count) AS total_repeat_passenger_count
    FROM dim_city a
        JOIN dim_repeat_trip_distribution b ON a.city_id = b.city_id
    GROUP BY a.city_name
)
SELECT tb.city_name,
    tb.total_repeat_passenger_count,
    ROUND(
        tb.total_repeat_passenger_count / (
            SELECT SUM(total_repeat_passenger_count)
            FROM tb_repeat
        ) * 100,
        2
    ) AS city_contribution_percentage
FROM tb_repeat tb
ORDER BY tb.total_repeat_passenger_count DESC;
-- 7. Monthly Target Achievement Analysis for Key Metrics