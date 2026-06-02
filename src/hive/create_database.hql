-- ============================================================================
-- TfL Data Warehouse - Hive Database Creation
-- Database: uttam_tfl
-- Purpose: Store TfL passenger data from HDFS
-- ============================================================================

-- Drop database if exists (careful in production!)
-- DROP DATABASE IF EXISTS uttam_tfl CASCADE;

-- Create database
CREATE DATABASE IF NOT EXISTS uttam_tfl
COMMENT 'Transport for London Data Warehouse'
LOCATION '/user/hive/warehouse/uttam_tfl.db';

-- Use the database
USE uttam_tfl;

-- Verify database creation
SHOW DATABASES LIKE 'uttam_tfl';
DESCRIBE DATABASE uttam_tfl;

SHOW TABLES;

-- Success message
SELECT 'Database uttam_tfl created successfully!' AS status;
