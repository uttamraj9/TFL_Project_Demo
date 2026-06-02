#!/bin/bash
# TfL Data Warehouse - Sqoop Import Script
# Imports all 6 tables from PostgreSQL to HDFS
# Target: /tmp/uttam/tfl_data/

set -e  # Exit on any error

# Database connection settings
export SQOOP_CONNECT="jdbc:postgresql://13.42.152.118:5432/testdb"
export SQOOP_USER="admin"
export SQOOP_PASS="admin123"
export TARGET_DIR="/tmp/uttam/tfl_data"

echo "================================================================================"
echo "TfL Data Warehouse - Sqoop Import to HDFS"
echo "================================================================================"
echo "Target Directory: $TARGET_DIR"
echo "Database: testdb @ 13.42.152.118:5432"
echo "Tables: 6 (dim_networks, dim_lines, dim_stations, dim_date, fact_station_lines, fact_passenger_entry_exit)"
echo "================================================================================"
echo ""

# Function to run sqoop import
import_table() {
    local table_name=$1
    local mapper_count=${2:-1}

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ${table_name} import..."

    sqoop import \
        --connect "$SQOOP_CONNECT" \
        --username "$SQOOP_USER" \
        --password "$SQOOP_PASS" \
        --table "$table_name" \
        --target-dir "$TARGET_DIR/$table_name" \
        --delete-target-dir \
        -m "$mapper_count"

    if [ $? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ ${table_name} import completed successfully"
        echo ""
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ${table_name} import FAILED"
        exit 1
    fi
}

# Import dimension tables first (smaller, no dependencies)
echo "=== Importing Dimension Tables ==="
import_table "dim_networks" 1
import_table "dim_lines" 1
import_table "dim_stations" 1
import_table "dim_date" 1

# Import bridge table
echo "=== Importing Bridge Table ==="
import_table "fact_station_lines" 1

# Import fact table (largest table - can use more mappers)
echo "=== Importing Fact Table ==="
import_table "fact_passenger_entry_exit" 2

echo "================================================================================"
echo "✓ All Sqoop imports completed successfully!"
echo "================================================================================"
echo "Imported Tables:"
echo "  • dim_networks (1 record)"
echo "  • dim_lines (14 records)"
echo "  • dim_stations (436 records)"
echo "  • dim_date (15 records)"
echo "  • fact_station_lines (575 records)"
echo "  • fact_passenger_entry_exit (4,771 records)"
echo ""
echo "HDFS Location: $TARGET_DIR"
echo ""
echo "To verify imports, run:"
echo "  hdfs dfs -ls $TARGET_DIR"
echo "  hdfs dfs -ls $TARGET_DIR/dim_stations"
echo "  hdfs dfs -cat $TARGET_DIR/dim_networks/part-m-00000 | head -10"
echo "================================================================================"
