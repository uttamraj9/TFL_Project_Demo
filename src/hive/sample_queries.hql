-- ============================================================================
-- TfL Data Warehouse - Sample Hive Queries
-- Database: uttam_tfl
-- ============================================================================

USE uttam_tfl;

-- ============================================================================
-- QUERY 1: Top 10 Busiest Stations in 2019
-- ============================================================================
SELECT
    s.station_name,
    SUM(f.total_entry_exit) AS total_passengers
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year = 2019
GROUP BY s.station_name
ORDER BY total_passengers DESC
LIMIT 10;

-- ============================================================================
-- QUERY 2: Stations by Line
-- ============================================================================
SELECT
    l.line_name,
    l.line_color,
    COUNT(DISTINCT sl.station_id) AS station_count
FROM dim_lines l
JOIN fact_station_lines sl ON l.line_id = sl.line_id
GROUP BY l.line_name, l.line_color
ORDER BY station_count DESC;

-- ============================================================================
-- QUERY 3: Year-over-Year Passenger Trends
-- ============================================================================
SELECT
    d.year,
    SUM(f.total_entry_exit) AS total_passengers,
    ROUND(SUM(f.total_entry_exit) / 1000000, 2) AS passengers_millions
FROM fact_passenger_entry_exit f
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.is_annual = TRUE
GROUP BY d.year
ORDER BY d.year;

-- ============================================================================
-- QUERY 4: Interchange Stations (Multiple Lines)
-- ============================================================================
SELECT
    s.station_name,
    COUNT(DISTINCT sl.line_id) AS number_of_lines
FROM dim_stations s
JOIN fact_station_lines sl ON s.station_id = sl.station_id
WHERE sl.is_interchange = TRUE
GROUP BY s.station_name
HAVING COUNT(DISTINCT sl.line_id) >= 3
ORDER BY number_of_lines DESC, s.station_name
LIMIT 20;

-- ============================================================================
-- QUERY 5: Night Tube Coverage by Line
-- ============================================================================
SELECT
    l.line_name,
    COUNT(DISTINCT s.station_id) AS total_stations,
    SUM(CASE WHEN s.has_night_tube THEN 1 ELSE 0 END) AS night_tube_stations,
    ROUND(
        (SUM(CASE WHEN s.has_night_tube THEN 1 ELSE 0 END) * 100.0) /
        COUNT(DISTINCT s.station_id),
        2
    ) AS coverage_percentage
FROM dim_lines l
JOIN fact_station_lines sl ON l.line_id = sl.line_id
JOIN dim_stations s ON sl.station_id = s.station_id
GROUP BY l.line_name
ORDER BY coverage_percentage DESC;

-- ============================================================================
-- QUERY 6: Passenger Growth 2017 vs 2019
-- ============================================================================
WITH yearly_stats AS (
    SELECT
        s.station_name,
        d.year,
        SUM(f.total_entry_exit) AS passengers
    FROM fact_passenger_entry_exit f
    JOIN dim_stations s ON f.station_id = s.station_id
    JOIN dim_date d ON f.date_id = d.date_id
    WHERE d.year IN (2017, 2019)
    GROUP BY s.station_name, d.year
)
SELECT
    station_name,
    MAX(CASE WHEN year = 2017 THEN passengers END) AS passengers_2017,
    MAX(CASE WHEN year = 2019 THEN passengers END) AS passengers_2019,
    (
        MAX(CASE WHEN year = 2019 THEN passengers END) -
        MAX(CASE WHEN year = 2017 THEN passengers END)
    ) AS growth,
    ROUND(
        ((MAX(CASE WHEN year = 2019 THEN passengers END) -
          MAX(CASE WHEN year = 2017 THEN passengers END)) * 100.0) /
        MAX(CASE WHEN year = 2017 THEN passengers END),
        2
    ) AS growth_percentage
FROM yearly_stats
GROUP BY station_name
HAVING MAX(CASE WHEN year = 2017 THEN passengers END) IS NOT NULL
   AND MAX(CASE WHEN year = 2019 THEN passengers END) IS NOT NULL
ORDER BY growth DESC
LIMIT 20;

-- ============================================================================
-- QUERY 7: Station Service Type Distribution
-- ============================================================================
SELECT
    'London Underground' AS service_type,
    COUNT(*) AS station_count
FROM dim_stations
WHERE has_london_underground = TRUE
UNION ALL
SELECT
    'Elizabeth Line',
    COUNT(*)
FROM dim_stations
WHERE has_elizabeth_line = TRUE
UNION ALL
SELECT
    'London Overground',
    COUNT(*)
FROM dim_stations
WHERE has_overground = TRUE
UNION ALL
SELECT
    'DLR',
    COUNT(*)
FROM dim_stations
WHERE has_dlr = TRUE
UNION ALL
SELECT
    'Night Tube',
    COUNT(*)
FROM dim_stations
WHERE has_night_tube = TRUE;

-- ============================================================================
-- QUERY 8: Average Passengers per Station by Year
-- ============================================================================
SELECT
    d.year,
    COUNT(DISTINCT f.station_id) AS station_count,
    SUM(f.total_entry_exit) AS total_passengers,
    ROUND(SUM(f.total_entry_exit) / COUNT(DISTINCT f.station_id), 0) AS avg_per_station
FROM fact_passenger_entry_exit f
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.is_annual = TRUE
GROUP BY d.year
ORDER BY d.year;

-- ============================================================================
-- QUERY 9: Stations with Most Consistent Passenger Numbers
-- ============================================================================
WITH station_stats AS (
    SELECT
        s.station_name,
        AVG(f.total_entry_exit) AS avg_passengers,
        STDDEV(f.total_entry_exit) AS stddev_passengers,
        COUNT(*) AS year_count
    FROM fact_passenger_entry_exit f
    JOIN dim_stations s ON f.station_id = s.station_id
    JOIN dim_date d ON f.date_id = d.date_id
    WHERE d.is_annual = TRUE
    GROUP BY s.station_name
    HAVING COUNT(*) >= 10
)
SELECT
    station_name,
    ROUND(avg_passengers, 0) AS avg_passengers,
    ROUND(stddev_passengers, 0) AS stddev_passengers,
    ROUND((stddev_passengers * 100.0) / avg_passengers, 2) AS coefficient_of_variation
FROM station_stats
WHERE avg_passengers > 1000000
ORDER BY coefficient_of_variation ASC
LIMIT 20;

-- ============================================================================
-- QUERY 10: Data Quality Check
-- ============================================================================
-- Check for records with potential data quality issues
SELECT
    'fact_passenger_entry_exit' AS table_name,
    'Records with zero passengers' AS issue,
    COUNT(*) AS count
FROM fact_passenger_entry_exit
WHERE total_entry_exit = 0
UNION ALL
SELECT
    'fact_passenger_entry_exit',
    'Records with NULL station_id',
    COUNT(*)
FROM fact_passenger_entry_exit
WHERE station_id IS NULL
UNION ALL
SELECT
    'fact_passenger_entry_exit',
    'Records with NULL date_id',
    COUNT(*)
FROM fact_passenger_entry_exit
WHERE date_id IS NULL
UNION ALL
SELECT
    'dim_stations',
    'Stations with NULL network_id',
    COUNT(*)
FROM dim_stations
WHERE network_id IS NULL;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 'Sample queries completed successfully!' AS status;
