--- NYC TAXI CLOUD ANALYTICS PROJECT
--- FINAL PROJECT SQL


---  check total count

SELECT COUNT(*)
FROM yellow_taxi;


--- check all the files by year and month
SELECT
    year,
    month,
    COUNT(*) AS trip_count
FROM yellow_taxi
GROUP BY year, month
ORDER BY year, month;

--- Check missing values
SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 ELSE 0 END)
        AS missing_pickup_datetime,

    SUM(CASE WHEN tpep_dropoff_datetime IS NULL THEN 1 ELSE 0 END)
        AS missing_dropoff_datetime,

    SUM(CASE WHEN pulocationid IS NULL THEN 1 ELSE 0 END)
        AS missing_pickup_location,

    SUM(CASE WHEN dolocationid IS NULL THEN 1 ELSE 0 END)
        AS missing_dropoff_location,

    SUM(CASE WHEN trip_distance IS NULL THEN 1 ELSE 0 END)
        AS missing_trip_distance,

    SUM(CASE WHEN fare_amount IS NULL THEN 1 ELSE 0 END)
        AS missing_fare,

    SUM(CASE WHEN tip_amount IS NULL THEN 1 ELSE 0 END)
        AS missing_tip,

    SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END)
        AS missing_total_amount

FROM yellow_taxi;

--- Check invalid values
SELECT
    SUM(CASE WHEN trip_distance <= 0 THEN 1 ELSE 0 END)
        AS invalid_distance,

    SUM(CASE WHEN fare_amount < 0 THEN 1 ELSE 0 END)
        AS negative_fare,

    SUM(CASE WHEN total_amount <= 0 THEN 1 ELSE 0 END)
        AS invalid_total_amount,

    SUM(
        CASE
            WHEN tpep_dropoff_datetime <= tpep_pickup_datetime
            THEN 1 ELSE 0
        END
    ) AS invalid_duration

FROM yellow_taxi;


--- Data profile outliers

SELECT
    MIN(trip_distance) AS min_distance,
    approx_percentile(trip_distance, 0.50) AS median_distance,
    approx_percentile(trip_distance, 0.95) AS p95_distance,
    approx_percentile(trip_distance, 0.99) AS p99_distance,
    MAX(trip_distance) AS max_distance,

    MIN(total_amount) AS min_total,
    approx_percentile(total_amount, 0.50) AS median_total,
    approx_percentile(total_amount, 0.95) AS p95_total,
    approx_percentile(total_amount, 0.99) AS p99_total,
    MAX(total_amount) AS max_total,

    MIN(date_diff(
        'minute',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    )) AS min_duration,

    approx_percentile(
        date_diff(
            'minute',
            tpep_pickup_datetime,
            tpep_dropoff_datetime
        ), 0.99
    ) AS p99_duration,

    MAX(date_diff(
        'minute',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    )) AS max_duration

FROM yellow_taxi;


--- cleaning impact check
    
SELECT
    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN trip_distance > 0
             AND trip_distance <= 100
             AND fare_amount >= 0
             AND total_amount > 0
             AND total_amount <= 500
             AND tpep_dropoff_datetime > tpep_pickup_datetime
             AND date_diff(
                    'minute',
                    tpep_pickup_datetime,
                    tpep_dropoff_datetime
                 ) <= 180
            THEN 1 ELSE 0
        END
    ) AS valid_rows,

    SUM(
        CASE
            WHEN NOT (
                trip_distance > 0
                AND trip_distance <= 100
                AND fare_amount >= 0
                AND total_amount > 0
                AND total_amount <= 500
                AND tpep_dropoff_datetime > tpep_pickup_datetime
                AND date_diff(
                       'minute',
                       tpep_pickup_datetime,
                       tpep_dropoff_datetime
                    ) <= 180
            )
            THEN 1 ELSE 0
        END
    ) AS rejected_rows

FROM yellow_taxi;

--- create silver cleaned dataset, standardize the column names and creates useful variable to analyze

CREATE TABLE silver_yellow_taxi
WITH (
    format = 'PARQUET',
    external_location = 's3://mgmt-59900-final-project/silver/yellow-taxi-clean/',
    partitioned_by = ARRAY['year', 'month']
)
AS
SELECT
    vendorid AS vendor_id,
    tpep_pickup_datetime AS pickup_datetime,
    tpep_dropoff_datetime AS dropoff_datetime,
    passenger_count,
    trip_distance,
    ratecodeid AS rate_code_id,
    store_and_fwd_flag,
    pulocationid AS pickup_location_id,
    dolocationid AS dropoff_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,

    date_diff(
        'minute',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    ) AS trip_duration_minutes,

    total_amount / trip_distance
        AS revenue_per_mile,

    total_amount /
        date_diff(
            'minute',
            tpep_pickup_datetime,
            tpep_dropoff_datetime
        )
        AS revenue_per_minute,

    hour(tpep_pickup_datetime)
        AS pickup_hour,

    day_of_week(tpep_pickup_datetime)
        AS pickup_day_of_week,

    year,
    month

FROM yellow_taxi

WHERE
    trip_distance > 0
    AND trip_distance <= 100

    AND fare_amount >= 0

    AND total_amount > 0
    AND total_amount <= 500

    AND tpep_dropoff_datetime > tpep_pickup_datetime

    AND date_diff(
        'minute',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    ) > 0

    AND date_diff(
        'minute',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    ) <= 180;



--- validate silver dataset
SELECT COUNT(*) AS silver_rows
FROM silver_yellow_taxi;

--- checking the data files created
SELECT
    year,
    month,
    COUNT(*) AS trip_count
FROM silver_yellow_taxi
GROUP BY year, month
ORDER BY year, month;





--- check invalid records if removed
SELECT
    SUM(CASE WHEN trip_distance <= 0 THEN 1 ELSE 0 END)
        AS invalid_distance,

    SUM(CASE WHEN trip_distance > 100 THEN 1 ELSE 0 END)
        AS excessive_distance,

    SUM(CASE WHEN fare_amount < 0 THEN 1 ELSE 0 END)
        AS negative_fare,

    SUM(CASE WHEN total_amount <= 0 THEN 1 ELSE 0 END)
        AS invalid_total,

    SUM(CASE WHEN total_amount > 500 THEN 1 ELSE 0 END)
        AS excessive_total,

    SUM(CASE WHEN trip_duration_minutes <= 0 THEN 1 ELSE 0 END)
        AS invalid_duration,

    SUM(CASE WHEN trip_duration_minutes > 180 THEN 1 ELSE 0 END)
        AS excessive_duration

FROM silver_yellow_taxi;


--- verify the Taxi Zone lookup table
SELECT *
FROM taxi_zone_lookup
LIMIT 10;



--- Create gold monthly performance table

CREATE TABLE gold_monthly_performance
WITH (
    format = 'PARQUET',
    external_location = 's3://mgmt-59900-final-project/gold/monthly-performance/'
)
AS
SELECT
    year,
    month,

    COUNT(*) AS total_trips,

    SUM(total_amount) AS total_revenue,

    AVG(fare_amount) AS average_fare,

    AVG(tip_amount) AS average_tip,

    AVG(trip_distance) AS average_trip_distance,

    AVG(trip_duration_minutes) AS average_trip_duration,

    SUM(total_amount) / NULLIF(SUM(trip_distance), 0)
        AS revenue_per_mile,

    SUM(total_amount) / NULLIF(SUM(trip_duration_minutes), 0)
        AS revenue_per_minute

FROM silver_yellow_taxi

GROUP BY
    year,
    month;
    
--- verify the gold table
SELECT *
FROM gold_monthly_performance
ORDER BY year, month;


--- check the zone lookup has unique ids
SELECT
    COUNT(*) AS total_zone_rows,
    COUNT(DISTINCT locationid) AS unique_location_ids
FROM taxi_zone_lookup;



--- Create gold zone performance table
CREATE TABLE gold_zone_performance
WITH (
    format = 'PARQUET',
    external_location =
        's3://mgmt-59900-final-project/gold/zone-performance/'
)
AS

SELECT
    t.year,
    t.month,

    t.pickup_location_id,

    COALESCE(z.borough, 'Unknown') AS pickup_borough,
    COALESCE(z.zone, 'Unknown') AS pickup_zone,

    COUNT(*) AS total_trips,

    SUM(t.total_amount) AS total_revenue,

    AVG(t.fare_amount) AS average_fare,

    AVG(t.tip_amount) AS average_tip,

    AVG(t.trip_distance) AS average_trip_distance,

    AVG(t.trip_duration_minutes) AS average_trip_duration,

    SUM(t.total_amount)
        / NULLIF(SUM(t.trip_distance), 0)
        AS revenue_per_mile,

    SUM(t.total_amount)
        / NULLIF(SUM(t.trip_duration_minutes), 0)
        AS revenue_per_minute

FROM silver_yellow_taxi t

LEFT JOIN taxi_zone_lookup z
    ON t.pickup_location_id = z.locationid

GROUP BY
    t.year,
    t.month,
    t.pickup_location_id,
    COALESCE(z.borough, 'Unknown'),
    COALESCE(z.zone, 'Unknown');
    
--- validate the gold zone performance table
SELECT *
FROM gold_zone_performance
ORDER BY year, month, total_trips DESC
LIMIT 20;

--- top 10 pickup zones
SELECT
    pickup_borough,
    pickup_zone,
    SUM(total_trips) AS trips,
    SUM(total_revenue) AS revenue
FROM gold_zone_performance
GROUP BY
    pickup_borough,
    pickup_zone
ORDER BY trips DESC
LIMIT 10;

--- create gold route performance table

CREATE TABLE gold_route_performance
WITH (
    format = 'PARQUET',
    external_location =
        's3://mgmt-59900-final-project/gold/route-performance/'
)
AS

SELECT
    t.year,
    t.month,

    t.pickup_location_id,
    pu.borough AS pickup_borough,
    pu.zone AS pickup_zone,

    t.dropoff_location_id,
    do.borough AS dropoff_borough,
    do.zone AS dropoff_zone,

    COUNT(*) AS total_trips,

    SUM(t.total_amount) AS total_revenue,

    AVG(t.fare_amount) AS average_fare,

    AVG(t.trip_distance) AS average_trip_distance,

    AVG(t.trip_duration_minutes) AS average_trip_duration,

    SUM(t.total_amount)
        / NULLIF(SUM(t.trip_distance), 0)
        AS revenue_per_mile,

    SUM(t.total_amount)
        / NULLIF(SUM(t.trip_duration_minutes), 0)
        AS revenue_per_minute

FROM silver_yellow_taxi t

LEFT JOIN taxi_zone_lookup pu
    ON t.pickup_location_id = pu.locationid

LEFT JOIN taxi_zone_lookup do
    ON t.dropoff_location_id = do.locationid

GROUP BY
    t.year,
    t.month,
    t.pickup_location_id,
    pu.borough,
    pu.zone,
    t.dropoff_location_id,
    do.borough,
    do.zone;
    
--- validating the gold route table and removing "NA"
SELECT
    REPLACE(pickup_zone, '"', '') AS pickup_zone,
    REPLACE(dropoff_zone, '"', '') AS dropoff_zone,
    SUM(total_trips) AS trips,
    SUM(total_revenue) AS revenue
FROM gold_route_performance
WHERE REPLACE(pickup_zone, '"', '') <> 'N/A'
  AND REPLACE(dropoff_zone, '"', '') <> 'N/A'
GROUP BY
    REPLACE(pickup_zone, '"', ''),
    REPLACE(dropoff_zone, '"', '')
HAVING SUM(total_trips) >= 1000
ORDER BY revenue DESC
LIMIT 10;


