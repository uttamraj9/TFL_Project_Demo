#!/bin/bash
# TfL Data Warehouse - Import with Custom Query
# Example: Import only 2019 passenger data

set -e

# Database connection settings
export SQOOP_CONNECT="jdbc:postgresql://13.42.152.118:5432/testdb"
export SQOOP_USER="admin"
export SQOOP_PASS="admin123"
export TARGET_DIR="/tmp/uttam/tfl_data_custom"

echo "================================================================================"
echo "TfL Data Warehouse - Custom Query Import"
echo "================================================================================"
echo "Example: Import only 2019 passenger data"
echo "Target: $TARGET_DIR/passenger_2019"
echo "================================================================================"
echo ""

# Import only 2019 data
sqoop import \
    -D mapreduce.framework.name=local \
    --connect "$SQOOP_CONNECT" \
    --username "$SQOOP_USER" \
    --password "$SQOOP_PASS" \
    --query "SELECT f.entry_exit_id, f.station_id, s.station_name, d.year, f.total_entry_exit, f.estimated_entries, f.estimated_exits FROM fact_passenger_entry_exit f JOIN dim_stations s ON f.station_id = s.station_id JOIN dim_date d ON f.date_id = d.date_id WHERE d.year = 2019 AND \$CONDITIONS" \
    --split-by f.entry_exit_id \
    --target-dir "$TARGET_DIR/passenger_2019" \
    --delete-target-dir \
    -m 2

echo ""
echo "================================================================================"
echo "✓ Custom query import completed!"
echo "================================================================================"
echo "HDFS Location: $TARGET_DIR/passenger_2019"
echo ""
echo "Imported data: 2019 passenger records with station names"
echo ""
echo "To view:"
echo "  hdfs dfs -cat $TARGET_DIR/passenger_2019/part-m-00000 | head -20"
echo ""
echo "Other custom query examples:"
echo ""
echo "# Import top 10 busiest stations"
echo "sqoop import \\"
echo "  --query 'SELECT s.station_name, SUM(f.total_entry_exit) as total FROM fact_passenger_entry_exit f JOIN dim_stations s ON f.station_id = s.station_id WHERE \$CONDITIONS GROUP BY s.station_name ORDER BY total DESC LIMIT 10' \\"
echo "  --split-by s.station_id \\"
echo "  --target-dir /tmp/uttam/top_stations"
echo ""
echo "# Import specific line data"
echo "sqoop import \\"
echo "  --query 'SELECT * FROM dim_stations s WHERE EXISTS (SELECT 1 FROM fact_station_lines sl JOIN dim_lines l ON sl.line_id = l.line_id WHERE sl.station_id = s.station_id AND l.line_name = \"Piccadilly\" AND \$CONDITIONS)' \\"
echo "  --split-by s.station_id \\"
echo "  --target-dir /tmp/uttam/piccadilly_stations"
echo "================================================================================"
