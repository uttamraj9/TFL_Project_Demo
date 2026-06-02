-- ============================================================================
-- TfL Data Warehouse - Hive Table Creation
-- Database: uttam_tfl
-- Tables: 6 (4 dimensions, 1 bridge, 1 fact)
-- ============================================================================

USE uttam_tfl;

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

-- Table 1: dim_networks
DROP TABLE IF EXISTS dim_networks;

CREATE EXTERNAL TABLE dim_networks (
    network_id INT COMMENT 'Primary key - Network identifier',
    network_name STRING COMMENT 'Name of the network (e.g., London Underground)',
    network_type STRING COMMENT 'Type classification (Underground, Rail)',
    created_at TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP COMMENT 'Record update timestamp'
)
COMMENT 'Dimension table for TfL network types'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_networks'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Table 2: dim_lines
DROP TABLE IF EXISTS dim_lines;

CREATE EXTERNAL TABLE dim_lines (
    line_id INT COMMENT 'Primary key - Line identifier',
    line_name STRING COMMENT 'Name of the line (e.g., Piccadilly, Central)',
    line_color STRING COMMENT 'Official TfL line color hex code',
    is_night_service BOOLEAN COMMENT 'Whether line offers night service',
    created_at TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP COMMENT 'Record update timestamp'
)
COMMENT 'Dimension table for individual tube/rail lines'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_lines'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Table 3: dim_stations
DROP TABLE IF EXISTS dim_stations;

CREATE EXTERNAL TABLE dim_stations (
    station_id INT COMMENT 'Primary key - Station identifier',
    nlc_code STRING COMMENT 'National Location Code',
    station_name STRING COMMENT 'Station name',
    network_id INT COMMENT 'Foreign key to dim_networks',
    has_london_underground BOOLEAN COMMENT 'Has Underground service',
    has_elizabeth_line BOOLEAN COMMENT 'Has Elizabeth line service',
    has_overground BOOLEAN COMMENT 'Has Overground service',
    has_dlr BOOLEAN COMMENT 'Has DLR service',
    has_night_tube BOOLEAN COMMENT 'Has Night Tube service',
    is_active BOOLEAN COMMENT 'Station currently active',
    created_at TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP COMMENT 'Record update timestamp'
)
COMMENT 'Dimension table for station master data'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_stations'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Table 4: dim_date
DROP TABLE IF EXISTS dim_date;

CREATE EXTERNAL TABLE dim_date (
    date_id INT COMMENT 'Primary key - Date identifier',
    year INT COMMENT 'Year (2007-2021)',
    quarter INT COMMENT 'Quarter (NULL for annual records)',
    month INT COMMENT 'Month (NULL for annual records)',
    is_annual BOOLEAN COMMENT 'Whether this is annual aggregate',
    period_label STRING COMMENT 'Human-readable period description',
    period_start DATE COMMENT 'Period start date',
    period_end DATE COMMENT 'Period end date',
    created_at TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Date dimension table for time-based analysis'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_date'
TBLPROPERTIES ('skip.header.line.count'='1');

-- ============================================================================
-- BRIDGE TABLE (Many-to-Many Relationship)
-- ============================================================================

-- Table 5: fact_station_lines
DROP TABLE IF EXISTS fact_station_lines;

CREATE EXTERNAL TABLE fact_station_lines (
    station_line_id INT COMMENT 'Primary key - Relationship identifier',
    station_id INT COMMENT 'Foreign key to dim_stations',
    line_id INT COMMENT 'Foreign key to dim_lines',
    is_interchange BOOLEAN COMMENT 'Station serves multiple lines',
    effective_from DATE COMMENT 'Relationship start date',
    effective_to STRING COMMENT 'Relationship end date (NULL if current)',
    created_at TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Bridge table for many-to-many station-line relationships'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/fact_station_lines'
TBLPROPERTIES ('skip.header.line.count'='1');

-- ============================================================================
-- FACT TABLE
-- ============================================================================

-- Table 6: fact_passenger_entry_exit
DROP TABLE IF EXISTS fact_passenger_entry_exit;

CREATE EXTERNAL TABLE fact_passenger_entry_exit (
    entry_exit_id BIGINT COMMENT 'Primary key - Transaction identifier',
    station_id INT COMMENT 'Foreign key to dim_stations',
    date_id INT COMMENT 'Foreign key to dim_date',
    total_entry_exit BIGINT COMMENT 'Total passenger movements',
    estimated_entries BIGINT COMMENT 'Estimated entries (50% of total)',
    estimated_exits BIGINT COMMENT 'Estimated exits (50% of total)',
    record_type STRING COMMENT 'Type of record (Annual, Monthly, etc.)',
    data_source STRING COMMENT 'Source of data',
    created_at TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Fact table containing passenger entry/exit statistics'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/fact_passenger_entry_exit'
TBLPROPERTIES ('skip.header.line.count'='1');

-- ============================================================================
-- VERIFY TABLE CREATION
-- ============================================================================

-- Show all tables
SHOW TABLES;

-- Count records in each table
SELECT 'dim_networks' AS table_name, COUNT(*) AS record_count FROM dim_networks
UNION ALL
SELECT 'dim_lines', COUNT(*) FROM dim_lines
UNION ALL
SELECT 'dim_stations', COUNT(*) FROM dim_stations
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'fact_station_lines', COUNT(*) FROM fact_station_lines
UNION ALL
SELECT 'fact_passenger_entry_exit', COUNT(*) FROM fact_passenger_entry_exit;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT 'All tables created successfully!' AS status;
SELECT 'Database: uttam_tfl' AS info;
SELECT 'Tables: 6 (4 dimensions, 1 bridge, 1 fact)' AS info;
SELECT 'Data loaded from: /tmp/uttam/tfl_data/' AS info;
