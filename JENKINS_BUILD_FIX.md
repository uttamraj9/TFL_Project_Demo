# Jenkins Build Fix - TfL Data Pipeline

## 🔴 Problem Identified

Your Jenkins job is **failing during SCP** because:
1. Target directory `/home/consultant/uttam/` doesn't exist on remote server
2. Need to create directory structure before copying files

**Error Message:**
```
scp -o StrictHostKeyChecking=no src/sqoop/import_all_tables.sh consultant@13.41.167.97:/home/consultant/uttam/
Build step 'Execute shell' marked build as failure
```

---

## ✅ Solution: Fix Jenkins Build Steps

### Current Job Configuration
- **Job Name:** `PG_to_HDFS_Sqoop_Uttam`
- **Git Repo:** https://github.com/uttamraj9/TFL_Project_Demo.git ✓ (Working)
- **Remote:** 13.41.167.97 (consultant/WelcomeItc@2026)

---

## 🔧 Step-by-Step Fix

### Option 1: Quick Fix (Single Build Step)

**Delete all existing build steps, add ONE "Execute shell" step:**

```bash
#!/bin/bash
set -e

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"
HDFS_TARGET="/tmp/uttam/tfl_data"

echo "=== TfL Data Pipeline Build ==="

# Step 1: Create directories on remote server
echo "Creating remote directories..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $PROJECT_DIR/src/sqoop $PROJECT_DIR/src/hive"

# Step 2: Copy Sqoop scripts
echo "Copying Sqoop scripts..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -r src/sqoop/* $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/sqoop/

# Step 3: Copy Hive scripts
echo "Copying Hive scripts..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -r src/hive/* $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/hive/

# Step 4: Make scripts executable
echo "Setting execute permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $PROJECT_DIR/src/sqoop/*.sh $PROJECT_DIR/src/hive/*.sh"

# Step 5: Clean HDFS
echo "Cleaning HDFS..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"

# Step 6: Run Sqoop import
echo "Running Sqoop import..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && bash src/sqoop/import_all_tables.sh"

# Step 7: Create Hive database
echo "Creating Hive database..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && hive -f src/hive/create_database.hql"

# Step 8: Create Hive tables
echo "Creating Hive tables..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && hive -f src/hive/create_tables.hql"

# Step 9: Verify
echo "Verifying HDFS..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -ls $HDFS_TARGET"

echo "Verifying Hive tables..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hive -e 'USE uttam_tfl; SHOW TABLES;'"

echo "✓ Pipeline completed successfully!"
```

**Save and click "Build Now"**

---

## 🎯 Option 2: Separate Build Steps (More Granular)

Replace your existing build steps with these **6 separate** "Execute shell" steps:

### Build Step 1: Prepare Remote Environment
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "=== Preparing Remote Environment ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $PROJECT_DIR/src/sqoop $PROJECT_DIR/src/hive"
echo "✓ Directories created"
```

### Build Step 2: Copy Scripts to Remote
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "=== Copying Scripts ==="
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -r src/sqoop/* $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/sqoop/

sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -r src/hive/* $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/hive/

sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $PROJECT_DIR/src/sqoop/*.sh $PROJECT_DIR/src/hive/*.sh"

echo "✓ Scripts copied and made executable"
```

### Build Step 3: Clean HDFS
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
HDFS_TARGET="/tmp/uttam/tfl_data"

echo "=== Cleaning HDFS ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true"
echo "✓ HDFS cleaned"
```

### Build Step 4: Run Sqoop Import
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "=== Running Sqoop Import ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && bash src/sqoop/import_all_tables.sh"
echo "✓ Sqoop import completed"
```

### Build Step 5: Create Hive Database and Tables
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "=== Creating Hive Database ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && hive -f src/hive/create_database.hql"

echo "=== Creating Hive Tables ==="
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && hive -f src/hive/create_tables.hql"
echo "✓ Hive setup completed"
```

### Build Step 6: Verify Pipeline
```bash
#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
HDFS_TARGET="/tmp/uttam/tfl_data"

echo "=== Verification ==="

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
    $REMOTE_USER@$REMOTE_HOST "hive -e \"USE uttam_tfl; SELECT 'dim_stations' AS tbl, COUNT(*) AS cnt FROM dim_stations;\""

echo ""
echo "✓ Pipeline completed successfully!"
```

---

## 🔍 Root Cause Analysis

### What Was Wrong:
```bash
# ✗ FAILED - Directory doesn't exist
scp src/sqoop/import_all_tables.sh consultant@13.41.167.97:/home/consultant/uttam/
```

### What's Fixed:
```bash
# ✓ FIXED - Create directory first
ssh consultant@13.41.167.97 "mkdir -p /home/consultant/uttam/TFL_Project_Demo/src/sqoop"

# Then copy
scp src/sqoop/* consultant@13.41.167.97:/home/consultant/uttam/TFL_Project_Demo/src/sqoop/
```

---

## 🧪 Test Before Full Run

### Create Test Job First

1. **New Item** → `Test_SSH_Connection` (Freestyle)
2. **Execute shell:**
   ```bash
   REMOTE_HOST="13.41.167.97"
   REMOTE_USER="consultant"
   REMOTE_PASSWORD="WelcomeItc@2026"
   
   echo "Testing SSH..."
   sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       $REMOTE_USER@$REMOTE_HOST "whoami && hostname && hdfs version"
   echo "✓ SSH working!"
   ```
3. **Build Now**
4. Check console - should show:
   ```
   Testing SSH...
   consultant
   cloudera-node
   Hadoop 3.x.x
   ✓ SSH working!
   ```

---

## 📋 Jenkins Job Configuration Checklist

### Source Code Management
- ✅ Git
- ✅ Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
- ✅ Branch: `*/main`
- ✅ No credentials needed (public repo)

### Build Environment
- ☑ Delete workspace before build starts (optional, recommended for clean builds)

### Build Steps
- ✅ Add "Execute shell" steps (as shown above)
- ✅ Use **Option 1** (single step) for simplicity
- ✅ Or **Option 2** (6 steps) for granular control

### Post-build Actions (Optional)
- ☑ Archive the artifacts: `*.log`
- ☑ E-mail Notification (if configured)

---

## 🎯 Expected Console Output (Success)

```
Started by user Consultant User
Running as SYSTEM
Building in workspace /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam
The recommended git tool is: NONE
 > git rev-parse --resolve-git-dir /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam/.git
Fetching changes from the remote Git repository
 > git fetch --tags --force --progress -- https://github.com/uttamraj9/TFL_Project_Demo.git
Checking out Revision 9a11fcf03cf912df5b0f418f11f95ad1fc1d38d6 (refs/remotes/origin/main)
 > git checkout -f 9a11fcf03cf912df5b0f418f11f95ad1fc1d38d6
[PG_to_HDFS_Sqoop_Uttam] $ /bin/sh -xe /tmp/jenkins.sh
+ === TfL Data Pipeline Build ===
+ Creating remote directories...
✓ Directories created
+ Copying Sqoop scripts...
✓ Scripts copied
+ Running Sqoop import...
✓ Sqoop import completed (6 tables)
+ Creating Hive database...
✓ Database created
+ Creating Hive tables...
✓ Tables created
+ Verifying HDFS...
drwxr-xr-x   - consultant hadoop          0 2026-06-02 10:30 /tmp/uttam/tfl_data/dim_networks
drwxr-xr-x   - consultant hadoop          0 2026-06-02 10:30 /tmp/uttam/tfl_data/dim_lines
...
+ Verifying Hive tables...
dim_networks
dim_lines
dim_stations
dim_date
fact_station_lines
fact_passenger_entry_exit
✓ Pipeline completed successfully!
Finished: SUCCESS
```

---

## 🐛 Troubleshooting

### Issue: "sshpass: command not found"

**Solution:** Install sshpass on Jenkins server
```bash
# SSH into Jenkins server
ssh jenkins@51.24.13.205

# Install sshpass
sudo yum install sshpass -y   # RHEL/CentOS
# OR
sudo apt-get install sshpass -y  # Ubuntu/Debian
```

### Issue: "Permission denied (publickey,password)"

**Solution 1:** Verify credentials
```bash
# Test from Jenkins server
ssh consultant@13.41.167.97
# Use password: WelcomeItc@2026
```

**Solution 2:** Check SSH server config on 13.41.167.97
```bash
# On Cloudera server
sudo vi /etc/ssh/sshd_config

# Ensure these are set:
PasswordAuthentication yes
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

### Issue: "hdfs: command not found" on remote

**Solution:** Add Hadoop to PATH in build script
```bash
# Add at beginning of SSH commands
export PATH=/usr/bin:/usr/local/bin:$PATH
export HADOOP_HOME=/usr/lib/hadoop
export PATH=$HADOOP_HOME/bin:$PATH
```

---

## 🔐 Security Note

**⚠️ Password in Plain Text**

Your current script has password in plain text. For production:

### Better Approach: Use SSH Key

1. **Generate SSH key on Jenkins server:**
   ```bash
   ssh-keygen -t rsa -f ~/.ssh/jenkins_cloudera -N ""
   ```

2. **Copy public key to Cloudera:**
   ```bash
   ssh-copy-id -i ~/.ssh/jenkins_cloudera.pub consultant@13.41.167.97
   ```

3. **Update Jenkins script (no password needed):**
   ```bash
   # Instead of sshpass
   ssh -i ~/.ssh/jenkins_cloudera consultant@13.41.167.97 "command"
   scp -i ~/.ssh/jenkins_cloudera file consultant@13.41.167.97:/path/
   ```

---

## ✅ Quick Action Items

1. **Update Jenkins Job:**
   - Delete existing build steps
   - Add ONE "Execute shell" step with **Option 1** script above
   - Save

2. **Build Now**

3. **Check Console Output**
   - Should show all ✓ checkmarks
   - Final message: "Pipeline completed successfully!"

4. **Verify on Cloudera:**
   ```bash
   ssh consultant@13.41.167.97
   
   # Check files
   ls -la /home/consultant/uttam/TFL_Project_Demo/src/
   
   # Check HDFS
   hdfs dfs -ls /tmp/uttam/tfl_data
   
   # Check Hive
   hive -e "USE uttam_tfl; SHOW TABLES;"
   ```

---

## 📞 Need Help?

If build still fails:
1. Copy the **complete console output**
2. Check which step failed
3. Run that step manually on Cloudera to debug

**Common failure points:**
- Network connectivity (Jenkins ↔ Cloudera)
- HDFS permissions
- PostgreSQL connectivity (Cloudera ↔ PostgreSQL)
- Hive permissions

---

*Last Updated: June 2, 2026*
*Issue: Fixed SCP directory creation*
*Status: Ready to use*
