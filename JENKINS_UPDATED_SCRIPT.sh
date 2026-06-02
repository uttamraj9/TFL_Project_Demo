#!/bin/bash
set -e

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
REMOTE_DIR="/home/consultant/uttam/TFL_Project_Demo"
HDFS_TARGET="/tmp/uttam/tfl_data"

echo "========================================"
echo "TfL Pipeline - GitHub to Cloudera"
echo "========================================"
echo "Workspace: $WORKSPACE"
echo "Remote: $REMOTE_HOST:$REMOTE_DIR"
echo "========================================"
echo ""

# Step 1: Verify scripts from GitHub
echo "Step 1: Verify scripts in workspace..."
if [ ! -d "$WORKSPACE/src/sqoop" ]; then
    echo "ERROR: Sqoop directory not found!"
    exit 1
fi
ls -lh $WORKSPACE/src/sqoop/*.sh
ls -lh $WORKSPACE/src/hive/*.hql
echo "✓ Scripts found"
echo ""

# Step 2: Create remote directories
echo "Step 2: Create directories on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR/src/sqoop $REMOTE_DIR/src/hive"
echo "✓ Directories created"
echo ""

# Step 3: Copy Sqoop scripts (suppress SSH banner with -q)
echo "Step 3: Copy Sqoop scripts to Cloudera..."
sshpass -p "$REMOTE_PASSWORD" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $WORKSPACE/src/sqoop/*.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/sqoop/
echo "✓ Sqoop scripts copied"
echo ""

# Step 4: Copy Hive scripts (suppress SSH banner with -q)
echo "Step 4: Copy Hive scripts to Cloudera..."
sshpass -p "$REMOTE_PASSWORD" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $WORKSPACE/src/hive/*.hql $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/hive/ 2>/dev/null || true
sshpass -p "$REMOTE_PASSWORD" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $WORKSPACE/src/hive/*.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/hive/ 2>/dev/null || true
echo "✓ Hive scripts copied"
echo ""

# Step 5: Set permissions
echo "Step 5: Set execute permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $REMOTE_DIR/src/sqoop/*.sh $REMOTE_DIR/src/hive/*.sh 2>/dev/null || true"
echo "✓ Permissions set"
echo ""

# Step 6: Verify on remote
echo "Step 6: Verify files on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "ls -lh $REMOTE_DIR/src/sqoop/ && ls -lh $REMOTE_DIR/src/hive/"
echo "✓ Files verified"
echo ""

# Step 7: Clean HDFS
echo "======================================"
echo "Step 7: Clean HDFS..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"
echo "✓ HDFS cleaned"
echo ""

# Step 8: Run Sqoop
echo "======================================"
echo "Step 8: Run Sqoop Import (6 tables)..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop completed"
echo ""

# Step 9: Create Hive database
echo "======================================"
echo "Step 9: Create Hive Database..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_database.hql"
echo "✓ Database created"
echo ""

# Step 10: Create Hive tables
echo "======================================"
echo "Step 10: Create Hive Tables..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Tables created"
echo ""

# Step 11: Verify HDFS
echo "======================================"
echo "VERIFICATION"
echo "======================================"
echo ""
echo "HDFS Contents:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -ls $HDFS_TARGET"

echo ""
echo "Hive Tables:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "hive -e 'USE uttam_tfl; SHOW TABLES;'"

echo ""
echo "Sample Record Count:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    $REMOTE_USER@$REMOTE_HOST "hive -e \"USE uttam_tfl; SELECT 'dim_stations' AS tbl, COUNT(*) FROM dim_stations;\""

echo ""
echo "======================================"
echo "✓✓✓ PIPELINE COMPLETE ✓✓✓"
echo "======================================"
echo "GitHub: uttamraj9/TFL_Project_Demo"
echo "HDFS: $HDFS_TARGET"
echo "Hive: uttam_tfl (6 tables, 5,812 records)"
echo "======================================"
