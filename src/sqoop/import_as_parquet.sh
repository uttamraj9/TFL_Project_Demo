#!/bin/bash
# TfL Data Warehouse - Import to Parquet Format
# Imports all tables as Parquet files for better performance
# Target: /tmp/uttam/tfl_data_parquet/

set -e

# Database connection settings
export SQOOP_CONNECT="jdbc:postgresql://13.42.152.118:5432/testdb"
export SQOOP_USER="admin"
export SQOOP_PASS="admin123"
export TARGET_DIR="/tmp/uttam/tfl_data_parquet"

echo "================================================================================"
echo "TfL Data Warehouse - Parquet Format Import"
echo "================================================================================"
echo "Target Directory: $TARGET_DIR"
echo "Format: Parquet (compressed)"
echo "================================================================================"
echo ""

# Function to import as parquet
import_parquet() {
    local table_name=$1
    local mapper_count=${2:-1}

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ${table_name} parquet import..."

    sqoop import \
        -D mapreduce.framework.name=local \
        --connect "$SQOOP_CONNECT" \
        --username "$SQOOP_USER" \
        --password "$SQOOP_PASS" \
        --table "$table_name" \
        --target-dir "$TARGET_DIR/$table_name" \
        --delete-target-dir \
        --as-parquetfile \
        --compression-codec snappy \
        -m "$mapper_count"

    if [ $? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ ${table_name} parquet import completed"
        echo ""
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ${table_name} parquet import FAILED"
        exit 1
    fi
}

# Import all tables as parquet
import_parquet "dim_networks" 1
import_parquet "dim_lines" 1
import_parquet "dim_stations" 1
import_parquet "dim_date" 1
import_parquet "fact_station_lines" 1
import_parquet "fact_passenger_entry_exit" 2

echo "================================================================================"
echo "✓ All Parquet imports completed successfully!"
echo "================================================================================"
echo "HDFS Location: $TARGET_DIR"
echo "Format: Parquet with Snappy compression"
echo ""
echo "Benefits of Parquet format:"
echo "  • 50-80% smaller file size"
echo "  • Faster query performance"
echo "  • Columnar storage"
echo "  • Better compression"
echo ""
echo "To verify:"
echo "  hdfs dfs -ls $TARGET_DIR"
echo "  hdfs dfs -ls $TARGET_DIR/dim_stations"
echo "================================================================================"
