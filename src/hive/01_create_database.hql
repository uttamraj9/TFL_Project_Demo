-- Create TfL Data Warehouse Database
-- Author: Uttam Kumar
-- Date: 2026-06-03

CREATE DATABASE IF NOT EXISTS uttam_tfl
COMMENT 'Transport for London Data Warehouse'
LOCATION '/user/hive/warehouse/uttam_tfl.db';

-- Verify database created
SHOW DATABASES LIKE 'uttam%';

-- Switch to the database
USE uttam_tfl;
