-- Create TfL Data Warehouse Tables
-- Author: Uttam Kumar
-- Date: 2026-06-03

USE uttam_tfl;

-- Drop tables if they exist
DROP TABLE IF EXISTS fact_passenger_entry_exit;
DROP TABLE IF EXISTS fact_station_lines;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_stations;
DROP TABLE IF EXISTS dim_lines;
DROP TABLE IF EXISTS dim_networks;

-- Dimension Table: Networks
CREATE EXTERNAL TABLE IF NOT EXISTS dim_networks (
    network_id INT,
    network_name STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_networks'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Dimension Table: Lines
CREATE EXTERNAL TABLE IF NOT EXISTS dim_lines (
    line_id INT,
    line_name STRING,
    network_id INT,
    line_color STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_lines'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Dimension Table: Stations
CREATE EXTERNAL TABLE IF NOT EXISTS dim_stations (
    station_id INT,
    station_name STRING,
    nlc_code STRING,
    os_grid_easting DOUBLE,
    os_grid_northing DOUBLE,
    latitude DOUBLE,
    longitude DOUBLE,
    postcode STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_stations'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Dimension Table: Date
CREATE EXTERNAL TABLE IF NOT EXISTS dim_date (
    date_id INT,
    year INT,
    period STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/dim_date'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Bridge Table: Station Lines
CREATE EXTERNAL TABLE IF NOT EXISTS fact_station_lines (
    station_line_id INT,
    station_id INT,
    line_id INT,
    effective_from STRING,
    effective_to STRING,
    is_interchange STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/fact_station_lines'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Fact Table: Passenger Entry Exit
CREATE EXTERNAL TABLE IF NOT EXISTS fact_passenger_entry_exit (
    entry_exit_id INT,
    station_id INT,
    date_id INT,
    total_entry_exit BIGINT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/uttam/tfl_data/fact_passenger_entry_exit'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Show all tables
SHOW TABLES;
