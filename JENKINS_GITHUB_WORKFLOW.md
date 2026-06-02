# Jenkins Build Using GitHub Repository Scripts

## 🎯 Workflow Overview

**Jenkins automatically clones your GitHub repo** → Scripts are in workspace → Copy to Cloudera → Execute

```
GitHub Repo (uttamraj9/TFL_Project_Demo)
    ↓ (git clone - automatic)
Jenkins Workspace (/var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam/)
    ├── src/sqoop/*.sh ✓ Already here
    └── src/hive/*.hql  ✓ Already here
    ↓ (scp copy)
Cloudera Cluster (13.41.167.97:/home/consultant/uttam/)
    ↓ (execute)
HDFS + Hive ✓
```

---

## ✅ Jenkins Build Step - Use Scripts from GitHub

Your Jenkins job **already clones the repo successfully**:
```
✓ git checkout -f 9a11fcf03cf912df5b0f418f11f95ad1fc1d38d6
✓ Commit message: "Add Jenkins freestyle project setup documentation"
```

**Scripts are already in Jenkins workspace!**

---

## 🔧 Updated Build Script - Using Workspace Scripts

Replace your Jenkins "Execute shell" build step with this:

```bash
#!/bin/bash
set -e

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
REMOTE_PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"
HDFS_TARGET="/tmp/uttam/tfl_data"

# Jenkins workspace (scripts already here from git clone)
WORKSPACE_DIR="${WORKSPACE}"

echo "=================================================="
echo "TfL Data Pipeline - Using GitHub Repository"
echo "=================================================="
echo "Jenkins Workspace: $WORKSPACE_DIR"
echo "Remote Host: $REMOTE_HOST"
echo "Remote Directory: $REMOTE_PROJECT_DIR"
echo "HDFS Target: $HDFS_TARGET"
echo "=================================================="
echo ""

# Verify scripts exist in workspace
echo "=== Step 1: Verify Scripts in Workspace ==="
ls -la $WORKSPACE_DIR/src/sqoop/
ls -la $WORKSPACE_DIR/src/hive/
echo "✓ Scripts found in workspace"
echo ""

# Create remote directory structure
echo "=== Step 2: Prepare Remote Directory ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PROJECT_DIR/src/sqoop $REMOTE_PROJECT_DIR/src/hive"
echo "✓ Remote directories created"
echo ""

# Copy Sqoop scripts from workspace to Cloudera
echo "=== Step 3: Copy Sqoop Scripts from GitHub to Cloudera ==="
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE_DIR/src/sqoop/*.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_PROJECT_DIR/src/sqoop/
echo "✓ Sqoop scripts copied"
echo ""

# Copy Hive scripts from workspace to Cloudera
echo "=== Step 4: Copy Hive Scripts from GitHub to Cloudera ==="
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE_DIR/src/hive/*.hql $WORKSPACE_DIR/src/hive/*.sh \
    $REMOTE_USER@$REMOTE_HOST:$REMOTE_PROJECT_DIR/src/hive/
echo "✓ Hive scripts copied"
echo ""

# Make scripts executable on remote
echo "=== Step 5: Set Execute Permissions ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $REMOTE_PROJECT_DIR/src/sqoop/*.sh $REMOTE_PROJECT_DIR/src/hive/*.sh"
echo "✓ Scripts made executable"
echo ""

# Verify files on remote
echo "=== Step 6: Verify Files on Cloudera ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "ls -lh $REMOTE_PROJECT_DIR/src/sqoop/ && ls -lh $REMOTE_PROJECT_DIR/src/hive/"
echo "✓ Files verified on remote"
echo ""

# Clean HDFS
echo "=== Step 7: Clean HDFS Target Directory ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"
echo "✓ HDFS cleaned"
echo ""

# Run Sqoop import
echo "=== Step 8: Execute Sqoop Import (6 Tables) ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_PROJECT_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop import completed"
echo ""

# Create Hive database
echo "=== Step 9: Create Hive Database ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_PROJECT_DIR && hive -f src/hive/create_database.hql"
echo "✓ Hive database created"
echo ""

# Create Hive tables
echo "=== Step 10: Create Hive Tables ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_PROJECT_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Hive tables created"
echo ""

# Verify HDFS
echo "=== Step 11: Verify HDFS Data ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -ls $HDFS_TARGET"
echo ""

# Verify Hive
echo "=== Step 12: Verify Hive Tables ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hive -e 'USE uttam_tfl; SHOW TABLES;'"
echo ""

# Count records
echo "=== Step 13: Count Records ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hive -e \"
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
echo "✓✓✓ TfL Data Pipeline COMPLETED SUCCESSFULLY ✓✓✓"
echo "=================================================="
echo "Source: GitHub (uttamraj9/TFL_Project_Demo)"
echo "Jenkins Workspace: $WORKSPACE_DIR"
echo "Cloudera: $REMOTE_HOST:$REMOTE_PROJECT_DIR"
echo "HDFS: $HDFS_TARGET (6 tables, 5,812 records)"
echo "Hive Database: uttam_tfl (6 tables)"
echo "=================================================="
```

---

## 📋 How It Works

### Automatic Git Clone (Jenkins does this)
```bash
# Jenkins automatically runs:
git clone https://github.com/uttamraj9/TFL_Project_Demo.git
# Into: /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam/
```

### Your Build Step Uses `$WORKSPACE`
```bash
# $WORKSPACE = /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam/
# Scripts are already here:
$WORKSPACE/src/sqoop/import_all_tables.sh
$WORKSPACE/src/hive/create_database.hql
```

### Copy to Cloudera
```bash
# From Jenkins workspace → To Cloudera
scp $WORKSPACE/src/sqoop/*.sh consultant@13.41.167.97:~/uttam/TFL_Project_Demo/src/sqoop/
```

### Execute on Cloudera
```bash
# On Cloudera cluster
ssh consultant@13.41.167.97 "cd ~/uttam/TFL_Project_Demo && bash src/sqoop/import_all_tables.sh"
```

---

## 🎯 Key Points

### ✅ What This Does:
1. **Jenkins clones GitHub repo** (automatic) → Scripts in workspace
2. **Verifies scripts exist** in Jenkins workspace
3. **Creates remote directories** on Cloudera
4. **Copies scripts from workspace** to Cloudera
5. **Makes scripts executable**
6. **Executes scripts** on Cloudera cluster
7. **Verifies results** (HDFS + Hive)

### ✅ Advantages:
- Always uses **latest scripts from GitHub**
- Single source of truth (GitHub repo)
- Easy to update: push to GitHub → Jenkins auto-pulls
- No manual script management

### ✅ Workflow:
```
You: git push to GitHub
  ↓
Jenkins: Automatically pulls latest code
  ↓
Jenkins: Copies scripts to Cloudera
  ↓
Cloudera: Executes Sqoop + Hive scripts
  ↓
Result: Data in HDFS + Hive ✓
```

---

## 🔄 Update Workflow

**When you change scripts:**

```bash
# On your Mac
cd /Users/uttamkumar/Downloads/TFL_Project_Demo

# Edit scripts
vi src/sqoop/import_all_tables.sh
vi src/hive/create_tables.hql

# Commit and push
git add src/
git commit -m "Update Sqoop/Hive scripts"
git push origin main

# In Jenkins: just click "Build Now"
# Jenkins will:
# 1. Pull latest code from GitHub (automatic)
# 2. Copy updated scripts to Cloudera
# 3. Execute them
```

**No manual copying needed!** 🎉

---

## 🧪 Test First

### Create Test Job to Verify Workspace

1. **New Item** → `Test_Workspace_Scripts` (Freestyle)
2. **Source Code Management** → Git
   - Repository: `https://github.com/uttamraj9/TFL_Project_Demo.git`
   - Branch: `*/main`
3. **Build** → Execute shell:
   ```bash
   echo "Workspace: $WORKSPACE"
   echo ""
   echo "=== Sqoop Scripts ==="
   ls -la $WORKSPACE/src/sqoop/
   echo ""
   echo "=== Hive Scripts ==="
   ls -la $WORKSPACE/src/hive/
   echo ""
   echo "=== File Contents Sample ==="
   head -10 $WORKSPACE/src/sqoop/import_all_tables.sh
   ```
4. **Build Now**
5. Check console output:
   ```
   Workspace: /var/lib/jenkins/workspace/Test_Workspace_Scripts
   
   === Sqoop Scripts ===
   -rw-r--r-- import_all_tables.sh
   -rw-r--r-- import_single_table.sh
   ...
   
   === Hive Scripts ===
   -rw-r--r-- create_database.hql
   -rw-r--r-- create_tables.hql
   ...
   
   ✓ Scripts found!
   ```

---

## 📊 Expected Console Output

```
Started by user Consultant User
Building in workspace /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
 > git fetch --tags --progress -- https://github.com/uttamraj9/TFL_Project_Demo.git
 > git checkout -f d0f2abc... (latest commit)
[PG_to_HDFS_Sqoop_Uttam] $ /bin/sh -xe /tmp/jenkins.sh

==================================================
TfL Data Pipeline - Using GitHub Repository
==================================================
Jenkins Workspace: /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
Remote Host: 13.41.167.97
Remote Directory: /home/consultant/uttam/TFL_Project_Demo
==================================================

=== Step 1: Verify Scripts in Workspace ===
-rwxr-xr-x import_all_tables.sh
-rwxr-xr-x import_single_table.sh
✓ Scripts found in workspace

=== Step 2: Prepare Remote Directory ===
✓ Remote directories created

=== Step 3: Copy Sqoop Scripts from GitHub to Cloudera ===
import_all_tables.sh                  100%  2KB
import_single_table.sh                100%  1KB
✓ Sqoop scripts copied

=== Step 4: Copy Hive Scripts from GitHub to Cloudera ===
create_database.hql                   100%  512B
create_tables.hql                     100%  4KB
✓ Hive scripts copied

=== Step 5: Set Execute Permissions ===
✓ Scripts made executable

... (Sqoop + Hive execution) ...

=== Step 13: Count Records ===
dim_networks        1
dim_lines          14
dim_stations      436
dim_date           15
fact_station_lines           575
fact_passenger_entry_exit  4,771

==================================================
✓✓✓ TfL Data Pipeline COMPLETED SUCCESSFULLY ✓✓✓
==================================================
Source: GitHub (uttamraj9/TFL_Project_Demo)
HDFS: /tmp/uttam/tfl_data (6 tables, 5,812 records)
Hive Database: uttam_tfl (6 tables)
==================================================

Finished: SUCCESS
```

---

## 🔍 Troubleshooting

### Issue: "No such file or directory" in workspace

**Check:**
```bash
# In Jenkins Execute shell
echo "Workspace: $WORKSPACE"
ls -R $WORKSPACE/src/
```

**If empty:** Git clone failed. Check:
- Repository URL is correct
- Branch name is `main` not `master`
- Repository is public (no credentials needed)

### Issue: "scp: No such file or directory" on remote

**Fix:** Create directories first (already in script)
```bash
ssh consultant@13.41.167.97 "mkdir -p /home/consultant/uttam/TFL_Project_Demo/src/{sqoop,hive}"
```

### Issue: Scripts have wrong permissions

**Fix:** After copy, set executable
```bash
ssh consultant@13.41.167.97 "chmod +x /home/consultant/uttam/TFL_Project_Demo/src/sqoop/*.sh"
```

---

## 🎯 Quick Action

1. **Open your Jenkins job:** http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/configure

2. **Verify Source Code Management is set:**
   - ✅ Git
   - ✅ Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
   - ✅ Branch: `*/main`

3. **Replace your "Execute shell" build step** with the script above

4. **Save** and click **"Build Now"**

5. **Watch console output** - should show:
   ```
   ✓ Scripts found in workspace (from GitHub)
   ✓ Scripts copied to Cloudera
   ✓ Pipeline completed successfully
   ```

---

## ✅ Summary

**Before (Manual):**
- Scripts manually maintained on Cloudera
- Hard to update and version control

**After (GitHub-based):**
- ✅ Jenkins automatically clones from GitHub
- ✅ Scripts always up-to-date
- ✅ Single source of truth (GitHub repo)
- ✅ Easy updates: push to GitHub → run Jenkins
- ✅ Version control and history

**This is the proper CI/CD way!** 🚀

---

*Last Updated: June 2, 2026*
*Source: GitHub Repository (uttamraj9/TFL_Project_Demo)*
