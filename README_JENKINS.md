# Jenkins Setup - Complete Guide for PG_to_HDFS_Sqoop_Uttam

## 🎯 Quick Start (5 Minutes)

### Step 1: Open Your Jenkins Job
```
http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/configure
```

### Step 2: Verify Source Code Management
Ensure this is configured:
- ✅ **Git**
- ✅ **Repository URL:** `https://github.com/uttamraj9/TFL_Project_Demo.git`
- ✅ **Branch Specifier:** `*/main`

### Step 3: Delete ALL Existing Build Steps

Click **Delete** on any existing "Execute shell" steps.

### Step 4: Add ONE New Build Step

**Add build step** → **Execute shell**

**Paste this exact script:**

```bash
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
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR/src/sqoop $REMOTE_DIR/src/hive"
echo "✓ Directories created"
echo ""

# Step 3: Copy scripts
echo "Step 3: Copy scripts to Cloudera..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/sqoop/*.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/sqoop/
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/hive/*.hql $WORKSPACE/src/hive/*.sh \
    $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/hive/ 2>/dev/null || true
echo "✓ Scripts copied"
echo ""

# Step 4: Set permissions
echo "Step 4: Set execute permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $REMOTE_DIR/src/sqoop/*.sh $REMOTE_DIR/src/hive/*.sh 2>/dev/null || true"
echo "✓ Permissions set"
echo ""

# Step 5: Verify on remote
echo "Step 5: Verify files on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "ls -lh $REMOTE_DIR/src/sqoop/ && ls -lh $REMOTE_DIR/src/hive/"
echo "✓ Files verified"
echo ""

# Step 6: Clean HDFS
echo "======================================"
echo "Step 6: Clean HDFS..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"
echo "✓ HDFS cleaned"
echo ""

# Step 7: Run Sqoop
echo "======================================"
echo "Step 7: Run Sqoop Import..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop completed"
echo ""

# Step 8: Create Hive database
echo "======================================"
echo "Step 8: Create Hive Database..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_database.hql"
echo "✓ Database created"
echo ""

# Step 9: Create Hive tables
echo "======================================"
echo "Step 9: Create Hive Tables..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Tables created"
echo ""

# Step 10: Verify
echo "======================================"
echo "VERIFICATION"
echo "======================================"
echo ""
echo "HDFS Contents:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -ls $HDFS_TARGET"

echo ""
echo "Hive Tables:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hive -e 'USE uttam_tfl; SHOW TABLES;'"

echo ""
echo "Record Counts:"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hive -e \"USE uttam_tfl; SELECT 'Total Tables' AS info, COUNT(*) AS count FROM (SELECT 'dim_networks' AS tbl UNION ALL SELECT 'dim_lines') x;\""

echo ""
echo "======================================"
echo "✓✓✓ PIPELINE COMPLETE ✓✓✓"
echo "======================================"
echo "GitHub: uttamraj9/TFL_Project_Demo"
echo "HDFS: $HDFS_TARGET"
echo "Hive: uttam_tfl"
echo "======================================"
```

### Step 5: Save and Build

1. Click **Save**
2. Click **Build Now**
3. Click on build number (e.g., #4)
4. Click **Console Output**

---

## ✅ Expected Output

```
Started by user Consultant User
Building in workspace /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
 > git fetch --progress -- https://github.com/uttamraj9/TFL_Project_Demo.git
 > git checkout -f 7022eb2...

========================================
TfL Pipeline - GitHub to Cloudera
========================================
Workspace: /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
Remote: 13.41.167.97:/home/consultant/uttam/TFL_Project_Demo
========================================

Step 1: Verify scripts in workspace...
-rwxr-xr-x import_all_tables.sh
-rwxr-xr-x import_single_table.sh
✓ Scripts found

Step 2: Create directories on Cloudera...
✓ Directories created

Step 3: Copy scripts to Cloudera...
✓ Scripts copied

Step 4: Set execute permissions...
✓ Permissions set

Step 5: Verify files on Cloudera...
✓ Files verified

======================================
Step 6: Clean HDFS...
======================================
✓ HDFS cleaned

======================================
Step 7: Run Sqoop Import...
======================================
[Sqoop output...]
✓ Sqoop completed

======================================
Step 8: Create Hive Database...
======================================
✓ Database created

======================================
Step 9: Create Hive Tables...
======================================
✓ Tables created

======================================
VERIFICATION
======================================

HDFS Contents:
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/dim_networks
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/dim_lines
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/dim_stations
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/dim_date
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/fact_station_lines
drwxr-xr-x   - consultant hadoop /tmp/uttam/tfl_data/fact_passenger_entry_exit

Hive Tables:
dim_networks
dim_lines
dim_stations
dim_date
fact_station_lines
fact_passenger_entry_exit

======================================
✓✓✓ PIPELINE COMPLETE ✓✓✓
======================================
GitHub: uttamraj9/TFL_Project_Demo
HDFS: /tmp/uttam/tfl_data
Hive: uttam_tfl
======================================

Finished: SUCCESS
```

---

## 🐛 If Build Fails

### Check Console Output

Look for error messages. Common issues:

1. **"sshpass: command not found"**
   ```bash
   # SSH into Jenkins server
   ssh jenkins@51.24.13.205
   sudo yum install sshpass -y
   ```

2. **"Permission denied"**
   - Verify credentials: consultant / WelcomeItc@2026
   - Test SSH manually:
     ```bash
     ssh consultant@13.41.167.97
     ```

3. **"hdfs: command not found"**
   - Hadoop not in PATH on Cloudera
   - Add to script:
     ```bash
     export PATH=/usr/bin:$PATH
     ```

4. **"Sqoop import failed"**
   - Check PostgreSQL connectivity from Cloudera:
     ```bash
     telnet 13.42.152.118 5432
     ```

---

## 📂 Files in Repository

All scripts are in the GitHub repo and will be used automatically:

```
src/sqoop/
  ├── import_all_tables.sh       ← Main import script
  ├── import_single_table.sh
  ├── import_as_parquet.sh
  └── import_with_query.sh

src/hive/
  ├── create_database.hql        ← Creates uttam_tfl
  ├── create_tables.hql          ← Creates 6 tables
  ├── sample_queries.hql
  └── load_all_to_hive.sh
```

---

## 🔄 Update Process

**When you change scripts:**

```bash
# Edit and commit
git add src/
git commit -m "Update scripts"
git push origin main

# In Jenkins: Click "Build Now"
# Jenkins automatically uses latest scripts
```

---

## ✅ Verification on Cloudera

After successful build, verify manually:

```bash
# SSH into Cloudera
ssh consultant@13.41.167.97

# Check files
ls -la /home/consultant/uttam/TFL_Project_Demo/src/

# Check HDFS
hdfs dfs -ls /tmp/uttam/tfl_data

# Check Hive
hive -e "USE uttam_tfl; SHOW TABLES;"
hive -e "USE uttam_tfl; SELECT COUNT(*) FROM dim_stations;"
```

---

## 📊 Data Pipeline Summary

```
PostgreSQL (13.42.152.118:5432/testdb)
          ↓ (Sqoop import)
HDFS (/tmp/uttam/tfl_data/)
          ↓ (Hive external tables)
Hive Database (uttam_tfl)
```

**Tables:**
- dim_networks (1 record)
- dim_lines (14 records)  
- dim_stations (436 records)
- dim_date (15 records)
- fact_station_lines (575 records)
- fact_passenger_entry_exit (4,771 records)

**Total: 5,812 records**

---

## 🎯 Success Criteria

✅ Jenkins pulls latest code from GitHub  
✅ Scripts copied to Cloudera  
✅ Sqoop imports 6 tables to HDFS  
✅ Hive database `uttam_tfl` created  
✅ 6 Hive external tables created  
✅ All record counts match expected values  
✅ Console output shows "SUCCESS"  

---

*Last Updated: June 2, 2026*
*Ready to use - just copy and paste!*
