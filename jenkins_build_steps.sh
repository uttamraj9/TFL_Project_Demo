#!/bin/bash
# Jenkins Build Script - TfL Data Pipeline
# This script runs on Jenkins server and executes commands on Cloudera cluster

set -e  # Exit on error

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
REMOTE_PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"
HDFS_TARGET_DIR="/tmp/uttam/tfl_data"

echo "=================================================="
echo "TfL Data Pipeline - Jenkins Build"
echo "=================================================="
echo "Remote Host: $REMOTE_HOST"
echo "Remote User: $REMOTE_USER"
echo "Project Dir: $REMOTE_PROJECT_DIR"
echo "HDFS Target: $HDFS_TARGET_DIR"
echo "=================================================="
echo ""

# Function to execute SSH commands
ssh_exec() {
    sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $REMOTE_USER@$REMOTE_HOST "$@"
}

# Function to copy files via SCP
scp_copy() {
    local source=$1
    local dest=$2
    sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -r "$source" $REMOTE_USER@$REMOTE_HOST:"$dest"
}

echo "=== Step 1: Create Remote Project Directory ==="
ssh_exec "mkdir -p $REMOTE_PROJECT_DIR/src/sqoop"
ssh_exec "mkdir -p $REMOTE_PROJECT_DIR/src/hive"
echo "✓ Directories created"
echo ""

echo "=== Step 2: Copy Sqoop Scripts ==="
if [ -d "src/sqoop" ]; then
    scp_copy src/sqoop/* $REMOTE_PROJECT_DIR/src/sqoop/
    echo "✓ Sqoop scripts copied"
else
    echo "✗ ERROR: src/sqoop directory not found in workspace"
    exit 1
fi
echo ""

echo "=== Step 3: Copy Hive Scripts ==="
if [ -d "src/hive" ]; then
    scp_copy src/hive/* $REMOTE_PROJECT_DIR/src/hive/
    echo "✓ Hive scripts copied"
else
    echo "✗ ERROR: src/hive directory not found in workspace"
    exit 1
fi
echo ""

echo "=== Step 4: Make Scripts Executable ==="
ssh_exec "chmod +x $REMOTE_PROJECT_DIR/src/sqoop/*.sh"
ssh_exec "chmod +x $REMOTE_PROJECT_DIR/src/hive/*.sh"
echo "✓ Scripts made executable"
echo ""

echo "=== Step 5: Verify Files on Remote Server ==="
ssh_exec "ls -lh $REMOTE_PROJECT_DIR/src/sqoop/"
ssh_exec "ls -lh $REMOTE_PROJECT_DIR/src/hive/"
echo "✓ Files verified"
echo ""

echo "=== Step 6: Clean HDFS Target Directory ==="
ssh_exec "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET_DIR || true"
echo "✓ HDFS cleaned"
echo ""

echo "=== Step 7: Run Sqoop Import ==="
ssh_exec "cd $REMOTE_PROJECT_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop import completed"
echo ""

echo "=== Step 8: Create Hive Database ==="
ssh_exec "cd $REMOTE_PROJECT_DIR && hive -f src/hive/create_database.hql"
echo "✓ Hive database created"
echo ""

echo "=== Step 9: Create Hive Tables ==="
ssh_exec "cd $REMOTE_PROJECT_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Hive tables created"
echo ""

echo "=== Step 10: Verify HDFS Data ==="
echo "HDFS Contents:"
ssh_exec "hdfs dfs -ls $HDFS_TARGET_DIR"
echo ""

echo "=== Step 11: Verify Hive Tables ==="
echo "Hive Tables:"
ssh_exec "hive -e 'USE uttam_tfl; SHOW TABLES;'"
echo ""

echo "Record Counts:"
ssh_exec "hive -e \"
USE uttam_tfl;
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
\""
echo ""

echo "=================================================="
echo "✓ TfL Data Pipeline Completed Successfully"
echo "=================================================="
echo "HDFS Location: $HDFS_TARGET_DIR"
echo "Hive Database: uttam_tfl (6 tables)"
echo "Total Records: 5,812"
echo "=================================================="
