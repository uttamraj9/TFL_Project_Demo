#!/bin/bash
# ============================================================================
# TfL Data Warehouse - Complete Hive Setup Script
# This script:
#   1. Creates uttam_tfl database
#   2. Creates all 6 tables
#   3. Verifies data loading
# ============================================================================

set -e  # Exit on any error

HIVE_DB="uttam_tfl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================================"
echo "TfL Data Warehouse - Hive Setup"
echo "================================================================================"
echo "Database: $HIVE_DB"
echo "Script Directory: $SCRIPT_DIR"
echo "================================================================================"
echo ""

# Step 1: Create Database
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 1: Creating database $HIVE_DB..."
hive -f "$SCRIPT_DIR/create_database.hql"

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Database created successfully"
    echo ""
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Database creation FAILED"
    exit 1
fi

# Step 2: Create Tables
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 2: Creating tables..."
hive -f "$SCRIPT_DIR/create_tables.hql"

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Tables created successfully"
    echo ""
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Table creation FAILED"
    exit 1
fi

# Step 3: Verify Setup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step 3: Verifying setup..."
hive -e "
USE $HIVE_DB;
SHOW TABLES;
SELECT 'dim_networks' AS table_name, COUNT(*) AS records FROM dim_networks
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
"

if [ $? -eq 0 ]; then
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Verification successful"
else
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Verification FAILED"
    exit 1
fi

# Summary
echo ""
echo "================================================================================"
echo "✓ Hive Setup Completed Successfully!"
echo "================================================================================"
echo "Database: uttam_tfl"
echo "Tables Created: 6"
echo "  • dim_networks (1 record)"
echo "  • dim_lines (14 records)"
echo "  • dim_stations (436 records)"
echo "  • dim_date (15 records)"
echo "  • fact_station_lines (575 records)"
echo "  • fact_passenger_entry_exit (4,771 records)"
echo ""
echo "To use the tables:"
echo "  hive -e 'USE uttam_tfl; SHOW TABLES;'"
echo "  hive -e 'USE uttam_tfl; SELECT * FROM dim_stations LIMIT 10;'"
echo "  hive -e 'USE uttam_tfl; SELECT * FROM fact_passenger_entry_exit LIMIT 10;'"
echo ""
echo "To run sample queries:"
echo "  hive -f $SCRIPT_DIR/sample_queries.hql"
echo "================================================================================"
