#!/bin/bash
# TfL Data Warehouse - Single Table Import Script
# Usage: ./import_single_table.sh <table_name> [mapper_count]
# Example: ./import_single_table.sh dim_stations 1

set -e

# Database connection settings
export SQOOP_CONNECT="jdbc:postgresql://13.42.152.118:5432/testdb"
export SQOOP_USER="admin"
export SQOOP_PASS="admin123"
export TARGET_DIR="/tmp/uttam/tfl_data"

# Check if table name provided
if [ -z "$1" ]; then
    echo "Error: Table name required"
    echo ""
    echo "Usage: $0 <table_name> [mapper_count]"
    echo ""
    echo "Available tables:"
    echo "  • dim_networks"
    echo "  • dim_lines"
    echo "  • dim_stations"
    echo "  • dim_date"
    echo "  • fact_station_lines"
    echo "  • fact_passenger_entry_exit"
    echo ""
    echo "Example: $0 dim_stations 1"
    exit 1
fi

TABLE_NAME=$1
MAPPER_COUNT=${2:-1}

echo "================================================================================"
echo "TfL Data Warehouse - Single Table Import"
echo "================================================================================"
echo "Table: $TABLE_NAME"
echo "Mappers: $MAPPER_COUNT"
echo "Target: $TARGET_DIR/$TABLE_NAME"
echo "================================================================================"
echo ""

sqoop import \
    -D mapreduce.framework.name=local \
    --connect "$SQOOP_CONNECT" \
    --username "$SQOOP_USER" \
    --password "$SQOOP_PASS" \
    --table "$TABLE_NAME" \
    --target-dir "$TARGET_DIR/$TABLE_NAME" \
    --delete-target-dir \
    -m "$MAPPER_COUNT"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================================================"
    echo "✓ Import completed successfully!"
    echo "================================================================================"
    echo "HDFS Location: $TARGET_DIR/$TABLE_NAME"
    echo ""
    echo "To view imported data:"
    echo "  hdfs dfs -ls $TARGET_DIR/$TABLE_NAME"
    echo "  hdfs dfs -cat $TARGET_DIR/$TABLE_NAME/part-m-00000 | head -10"
    echo "================================================================================"
else
    echo ""
    echo "✗ Import FAILED"
    exit 1
fi
