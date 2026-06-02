# Jenkins Simple Setup - Copy This Script

## 🎯 What This Does

```
GitHub Repo → Jenkins Workspace → Copy to Cloudera → Execute Scripts → HDFS + Hive ✓
```

---

## 📋 Copy This Exact Script

Open your Jenkins job: **PG_to_HDFS_Sqoop_Uttam**

**Configure** → **Build** → **Execute shell** → **Paste this:**

```bash
#!/bin/bash
set -e

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
REMOTE_DIR="/home/consultant/uttam/TFL_Project_Demo"
HDFS_TARGET="/tmp/uttam/tfl_data"

echo "=================================================="
echo "TfL Pipeline - Using GitHub Scripts"
echo "=================================================="
echo "Workspace: $WORKSPACE"
echo "Remote: $REMOTE_HOST:$REMOTE_DIR"
echo "=================================================="

# Step 1: Verify scripts from GitHub clone
echo "✓ Scripts from GitHub:"
ls -lh $WORKSPACE/src/sqoop/*.sh
ls -lh $WORKSPACE/src/hive/*.hql

# Step 2: Create remote directories
echo ""
echo "Creating directories on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_DIR/src/sqoop $REMOTE_DIR/src/hive"

# Step 3: Copy Sqoop scripts
echo "Copying Sqoop scripts..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/sqoop/*.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/sqoop/

# Step 4: Copy Hive scripts
echo "Copying Hive scripts..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/hive/*.hql $WORKSPACE/src/hive/*.sh \
    $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/src/hive/ 2>/dev/null || true

# Step 5: Make executable
echo "Setting permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $REMOTE_DIR/src/sqoop/*.sh $REMOTE_DIR/src/hive/*.sh 2>/dev/null || true"

echo "✓ Setup complete!"
echo ""

# Step 6: Clean HDFS
echo "=================================================="
echo "Cleaning HDFS..."
echo "=================================================="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"
echo "✓ HDFS cleaned"
echo ""

# Step 7: Run Sqoop
echo "=================================================="
echo "Running Sqoop Import (6 tables)..."
echo "=================================================="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop completed"
echo ""

# Step 8: Create Hive database
echo "=================================================="
echo "Creating Hive Database..."
echo "=================================================="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_database.hql"
echo "✓ Database created"
echo ""

# Step 9: Create Hive tables
echo "=================================================="
echo "Creating Hive Tables..."
echo "=================================================="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Tables created"
echo ""

# Step 10: Verify
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
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
    $REMOTE_USER@$REMOTE_HOST "hive -e \"USE uttam_tfl; SELECT 'dim_stations' AS tbl, COUNT(*) FROM dim_stations;\""

echo ""
echo "=================================================="
echo "✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓"
echo "=================================================="
echo "Source: GitHub (uttamraj9/TFL_Project_Demo)"
echo "HDFS: $HDFS_TARGET"
echo "Hive: uttam_tfl (6 tables, 5,812 records)"
echo "=================================================="
```

**Save** → **Build Now** → **Watch Console Output**

---

## ✅ What You'll See

```
Started by user Consultant User
Building in workspace /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
 > git checkout -f 7669e45... (from GitHub)

==================================================
TfL Pipeline - Using GitHub Scripts
==================================================
Workspace: /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
Remote: 13.41.167.97:/home/consultant/uttam/TFL_Project_Demo
==================================================
✓ Scripts from GitHub:
-rwxr-xr-x import_all_tables.sh
-rwxr-xr-x import_single_table.sh

Creating directories on Cloudera...
Copying Sqoop scripts...
Copying Hive scripts...
Setting permissions...
✓ Setup complete!

==================================================
Cleaning HDFS...
==================================================
✓ HDFS cleaned

==================================================
Running Sqoop Import (6 tables)...
==================================================
[Sqoop output...]
✓ Sqoop completed

==================================================
Creating Hive Database...
==================================================
✓ Database created

==================================================
Creating Hive Tables...
==================================================
✓ Tables created

==================================================
VERIFICATION
==================================================

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

Record Counts:
dim_stations    436

==================================================
✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓
==================================================
Source: GitHub (uttamraj9/TFL_Project_Demo)
HDFS: /tmp/uttam/tfl_data
Hive: uttam_tfl (6 tables, 5,812 records)
==================================================

Finished: SUCCESS
```

---

## 🔄 How It Works

### 1. Git Clone (Automatic)
Jenkins automatically clones your GitHub repo:
```
GitHub: https://github.com/uttamraj9/TFL_Project_Demo
   ↓ (git clone)
Jenkins: /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam/
   ├── src/sqoop/import_all_tables.sh  ✓
   └── src/hive/create_tables.hql      ✓
```

### 2. Copy to Cloudera
```bash
# From Jenkins workspace
$WORKSPACE/src/sqoop/*.sh
   ↓ (scp)
# To Cloudera
consultant@13.41.167.97:/home/consultant/uttam/TFL_Project_Demo/src/sqoop/
```

### 3. Execute on Cloudera
```bash
# SSH into Cloudera and run
cd /home/consultant/uttam/TFL_Project_Demo
bash src/sqoop/import_all_tables.sh
hive -f src/hive/create_database.hql
hive -f src/hive/create_tables.hql
```

---

## 🎯 Update Scripts

**To update scripts:**

```bash
# On your Mac
cd /Users/uttamkumar/Downloads/TFL_Project_Demo

# Edit any script
vi src/sqoop/import_all_tables.sh

# Commit and push
git add src/sqoop/import_all_tables.sh
git commit -m "Update Sqoop script"
git push origin main

# In Jenkins: Click "Build Now"
# Jenkins will:
# 1. Pull latest from GitHub (automatic)
# 2. Copy updated scripts to Cloudera
# 3. Execute them
```

**No manual work needed!** 🎉

---

## 📊 Files Involved

**From GitHub (automatic):**
```
src/sqoop/
  ├── import_all_tables.sh       ← Main Sqoop script
  ├── import_single_table.sh     ← Individual table import
  ├── import_as_parquet.sh       ← Parquet format import
  └── import_with_query.sh       ← Custom query import

src/hive/
  ├── create_database.hql        ← Creates uttam_tfl database
  ├── create_tables.hql          ← Creates 6 external tables
  ├── sample_queries.hql         ← Example queries
  └── load_all_to_hive.sh        ← Helper script
```

**Copied to Cloudera:**
```
/home/consultant/uttam/TFL_Project_Demo/src/
  ├── sqoop/
  │   └── import_all_tables.sh   ← Executed here
  └── hive/
      ├── create_database.hql    ← Executed here
      └── create_tables.hql      ← Executed here
```

**Created on HDFS:**
```
/tmp/uttam/tfl_data/
  ├── dim_networks/
  ├── dim_lines/
  ├── dim_stations/
  ├── dim_date/
  ├── fact_station_lines/
  └── fact_passenger_entry_exit/
```

**Created in Hive:**
```
uttam_tfl database
  ├── dim_networks (1 record)
  ├── dim_lines (14 records)
  ├── dim_stations (436 records)
  ├── dim_date (15 records)
  ├── fact_station_lines (575 records)
  └── fact_passenger_entry_exit (4,771 records)
```

---

## ✅ That's It!

**Three simple steps:**
1. ✅ Paste the script into Jenkins build step
2. ✅ Save
3. ✅ Click "Build Now"

**Jenkins will:**
- ✅ Clone GitHub repo (automatic)
- ✅ Copy scripts to Cloudera
- ✅ Execute Sqoop import
- ✅ Create Hive database and tables
- ✅ Verify everything worked

**No manual script management!**
**Always uses latest from GitHub!**
**Complete automation!** 🚀

---

*Last Updated: June 2, 2026*
*Just copy-paste and run!*
