# Jenkins Freestyle Project Setup for TfL Data Pipeline
# Connecting Jenkins to Cloudera Cluster

## 📋 Overview

This guide configures a Jenkins freestyle project at **http://51.24.13.205:8081/** to:
1. Connect to Cloudera cluster via SSH
2. Run Sqoop scripts to import data from PostgreSQL to HDFS
3. Execute Hive queries to create database and tables
4. Orchestrate the complete TfL data pipeline

---

## 🔧 Prerequisites

### 1. Cloudera Cluster Access
- **Cluster Host**: Your Cloudera edge/gateway node IP/hostname
- **SSH User**: Username with Hadoop access
- **SSH Key/Password**: Authentication credentials
- **Required Tools**: sqoop, hive, hdfs, hadoop

### 2. Jenkins Server
- **URL**: http://51.24.13.205:8081/
- **Required Plugins**:
  - SSH Agent Plugin (for SSH key management)
  - Publish Over SSH Plugin (for SSH connections)
  - AnsiColor Plugin (for colored console output)
  - Workspace Cleanup Plugin (optional)

### 3. Network Access
- Jenkins server can SSH to Cloudera cluster
- Cloudera cluster can connect to PostgreSQL (13.42.152.118:5432)

---

## 📦 Step 1: Install Required Jenkins Plugins

1. Go to: **Manage Jenkins** → **Manage Plugins** → **Available**
2. Install these plugins:
   ```
   ☑ SSH Agent Plugin
   ☑ Publish Over SSH Plugin
   ☑ AnsiColor Plugin
   ☑ Workspace Cleanup Plugin
   ```
3. Click **Install without restart**

---

## 🔐 Step 2: Configure SSH Credentials

### Option A: SSH Private Key (Recommended)

1. Go to: **Manage Jenkins** → **Manage Credentials** → **(global)** → **Add Credentials**
2. Configure:
   ```
   Kind: SSH Username with private key
   ID: cloudera-cluster-ssh
   Description: Cloudera Cluster SSH Access
   Username: <your_cloudera_username>
   Private Key: [Enter directly or from file]
   Passphrase: <if your key has one>
   ```

### Option B: Username/Password

1. Add Credentials with:
   ```
   Kind: Username with password
   ID: cloudera-cluster-ssh
   Description: Cloudera Cluster SSH Access
   Username: <your_cloudera_username>
   Password: <your_password>
   ```

---

## 🌐 Step 3: Configure SSH Server Connection

1. Go to: **Manage Jenkins** → **Configure System**
2. Scroll to **SSH remote hosts** section
3. Click **Add** and configure:

```
Hostname: <cloudera_edge_node_ip_or_hostname>
Port: 22
Credentials: Select "cloudera-cluster-ssh"
```

4. Click **Check connection** to verify
5. Click **Save**

---

## 📁 Step 4: Prepare Scripts on Cloudera Cluster

### Copy Scripts to Cluster

**Option A: Using SCP from your laptop**
```bash
# From TFL_Project_Demo directory
scp -r src/sqoop/* <user>@<cloudera_host>:/home/<user>/tfl_project/sqoop/
scp -r src/hive/* <user>@<cloudera_host>:/home/<user>/tfl_project/hive/
```

**Option B: Using Git on Cluster**
```bash
# SSH into cluster
ssh <user>@<cloudera_host>

# Clone repository
cd ~
git clone https://github.com/uttamraj9/TFL_Project_Demo.git
cd TFL_Project_Demo

# Make scripts executable
chmod +x src/sqoop/*.sh
chmod +x src/hive/*.sh
```

**Verify files exist:**
```bash
ls -la ~/TFL_Project_Demo/src/sqoop/
ls -la ~/TFL_Project_Demo/src/hive/
```

---

## 🚀 Step 5: Create Jenkins Freestyle Project

### 5.1 Create New Project

1. Click **New Item**
2. Enter name: `TfL-Data-Pipeline`
3. Select: **Freestyle project**
4. Click **OK**

### 5.2 General Configuration

**Description:**
```
TfL Data Warehouse Pipeline - Sqoop Import + Hive Table Creation
Imports 6 tables from PostgreSQL to HDFS and creates Hive external tables
Database: uttam_tfl
```

**✓ Discard old builds**
- Max # of builds to keep: `10`

**✓ This project is parameterized** (Add these parameters)

| Parameter Type | Name | Default Value | Description |
|----------------|------|---------------|-------------|
| String | `PROJECT_DIR` | `/home/<user>/TFL_Project_Demo` | Project directory on cluster |
| String | `HDFS_TARGET` | `/tmp/uttam/tfl_data` | HDFS target directory |
| Choice | `STEP` | `ALL` | Choices: `ALL`, `SQOOP_ONLY`, `HIVE_ONLY` |
| Boolean | `CLEAN_HDFS` | `true` | Delete HDFS data before import |

---

## 📝 Step 6: Configure Build Steps

### Build Step 1: Clean HDFS (Optional)

**Build Step Type:** Execute shell script on remote host using ssh

```bash
#!/bin/bash
set -e  # Exit on error

echo "==============================================="
echo "Step 1: Clean HDFS Target Directory"
echo "==============================================="

if [ "$CLEAN_HDFS" = "true" ]; then
    echo "Cleaning HDFS: $HDFS_TARGET"
    hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true
    echo "✓ HDFS cleaned"
else
    echo "Skipping HDFS cleanup (CLEAN_HDFS=false)"
fi

echo ""
```

### Build Step 2: Run Sqoop Import

**Build Step Type:** Execute shell script on remote host using ssh

```bash
#!/bin/bash
set -e

echo "==============================================="
echo "Step 2: Sqoop Import from PostgreSQL to HDFS"
echo "==============================================="

if [ "$STEP" = "SQOOP_ONLY" ] || [ "$STEP" = "ALL" ]; then
    cd $PROJECT_DIR
    
    echo "Running Sqoop import script..."
    bash src/sqoop/import_all_tables.sh
    
    echo ""
    echo "Verifying HDFS imports..."
    hdfs dfs -ls $HDFS_TARGET
    
    echo ""
    echo "✓ Sqoop import completed"
else
    echo "Skipping Sqoop (STEP=$STEP)"
fi

echo ""
```

### Build Step 3: Create Hive Database

**Build Step Type:** Execute shell script on remote host using ssh

```bash
#!/bin/bash
set -e

echo "==============================================="
echo "Step 3: Create Hive Database"
echo "==============================================="

if [ "$STEP" = "HIVE_ONLY" ] || [ "$STEP" = "ALL" ]; then
    cd $PROJECT_DIR
    
    echo "Creating Hive database uttam_tfl..."
    hive -f src/hive/create_database.hql
    
    echo "✓ Hive database created"
else
    echo "Skipping Hive database creation (STEP=$STEP)"
fi

echo ""
```

### Build Step 4: Create Hive Tables

**Build Step Type:** Execute shell script on remote host using ssh

```bash
#!/bin/bash
set -e

echo "==============================================="
echo "Step 4: Create Hive External Tables"
echo "==============================================="

if [ "$STEP" = "HIVE_ONLY" ] || [ "$STEP" = "ALL" ]; then
    cd $PROJECT_DIR
    
    echo "Creating 6 Hive external tables..."
    hive -f src/hive/create_tables.hql
    
    echo ""
    echo "Verifying table creation..."
    hive -e "USE uttam_tfl; SHOW TABLES;"
    
    echo ""
    echo "Counting records..."
    hive -e "
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
    "
    
    echo "✓ Hive tables created and loaded"
else
    echo "Skipping Hive table creation (STEP=$STEP)"
fi

echo ""
```

### Build Step 5: Final Summary

**Build Step Type:** Execute shell script on remote host using ssh

```bash
#!/bin/bash

echo "==============================================="
echo "Pipeline Execution Summary"
echo "==============================================="
echo "✓ Step 1: HDFS Cleanup - COMPLETED"
echo "✓ Step 2: Sqoop Import - COMPLETED"
echo "✓ Step 3: Hive Database - COMPLETED"
echo "✓ Step 4: Hive Tables - COMPLETED"
echo "==============================================="
echo ""
echo "Access Hive tables:"
echo "  beeline -u jdbc:hive2://localhost:10000 -e 'USE uttam_tfl; SHOW TABLES;'"
echo ""
echo "HDFS Location: $HDFS_TARGET"
echo "  hdfs dfs -ls $HDFS_TARGET"
echo ""
echo "==============================================="
echo "TfL Data Pipeline Execution: SUCCESS"
echo "==============================================="
```

---

## 🎨 Step 7: Post-Build Actions (Optional)

### Email Notification

1. Add Post-build Action: **E-mail Notification**
2. Configure:
   ```
   Recipients: your-email@example.com
   ☑ Send e-mail for every unstable build
   ☑ Send separate e-mails to individuals who broke the build
   ```

### Archive Build Logs

1. Add Post-build Action: **Archive the artifacts**
2. Files to archive: `*.log`

---

## 🔧 Alternative: Single Script Approach

If you prefer one script instead of multiple build steps:

### Create Master Script on Cluster

Create file: `~/TFL_Project_Demo/run_pipeline.sh`

```bash
#!/bin/bash
# TfL Data Pipeline Master Script
# Usage: ./run_pipeline.sh [all|sqoop|hive]

set -e

PROJECT_DIR="/home/$(whoami)/TFL_Project_Demo"
HDFS_TARGET="/tmp/uttam/tfl_data"
STEP="${1:-all}"

echo "==============================================="
echo "TfL Data Pipeline Execution"
echo "==============================================="
echo "Step: $STEP"
echo "Project Dir: $PROJECT_DIR"
echo "HDFS Target: $HDFS_TARGET"
echo "==============================================="
echo ""

cd $PROJECT_DIR

# Step 1: Clean HDFS
if [ "$STEP" = "all" ] || [ "$STEP" = "sqoop" ]; then
    echo "=== Step 1: Cleaning HDFS ==="
    hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true
    echo "✓ HDFS cleaned"
    echo ""
fi

# Step 2: Sqoop Import
if [ "$STEP" = "all" ] || [ "$STEP" = "sqoop" ]; then
    echo "=== Step 2: Sqoop Import ==="
    bash src/sqoop/import_all_tables.sh
    echo "✓ Sqoop import completed"
    echo ""
fi

# Step 3: Create Hive Database
if [ "$STEP" = "all" ] || [ "$STEP" = "hive" ]; then
    echo "=== Step 3: Hive Database Creation ==="
    hive -f src/hive/create_database.hql
    echo "✓ Hive database created"
    echo ""
fi

# Step 4: Create Hive Tables
if [ "$STEP" = "all" ] || [ "$STEP" = "hive" ]; then
    echo "=== Step 4: Hive Table Creation ==="
    hive -f src/hive/create_tables.hql
    echo "✓ Hive tables created"
    echo ""
fi

# Verification
echo "=== Pipeline Verification ==="
echo "HDFS Contents:"
hdfs dfs -ls $HDFS_TARGET

echo ""
echo "Hive Tables:"
hive -e "USE uttam_tfl; SHOW TABLES;"

echo ""
echo "Record Counts:"
hive -e "
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
"

echo ""
echo "==============================================="
echo "✓ TfL Data Pipeline: SUCCESS"
echo "==============================================="
```

**Make executable:**
```bash
chmod +x ~/TFL_Project_Demo/run_pipeline.sh
```

### Jenkins Build Step (Single Script)

**Execute shell script on remote host using ssh:**

```bash
#!/bin/bash
cd /home/<user>/TFL_Project_Demo
./run_pipeline.sh all
```

---

## 🧪 Step 8: Test the Pipeline

### 8.1 Test SSH Connection First

Create a test job:
1. New Item → `Test-Cloudera-Connection` (Freestyle)
2. Add build step: Execute shell script on remote host using ssh
3. Script:
   ```bash
   echo "Testing connection..."
   whoami
   hostname
   hdfs version
   hive --version
   echo "✓ Connection successful!"
   ```
4. Save and Build

### 8.2 Run TfL Pipeline

1. Go to project: `TfL-Data-Pipeline`
2. Click **Build with Parameters**
3. Set parameters:
   ```
   PROJECT_DIR: /home/<user>/TFL_Project_Demo
   HDFS_TARGET: /tmp/uttam/tfl_data
   STEP: ALL
   CLEAN_HDFS: true
   ```
4. Click **Build**

### 8.3 Monitor Execution

- Click **Console Output** to watch real-time logs
- Should see:
  ```
  ✓ HDFS cleaned
  ✓ Sqoop import completed (6 tables)
  ✓ Hive database created
  ✓ Hive tables created
  ✓ Pipeline SUCCESS
  ```

---

## 🔄 Step 9: Schedule Automation (Optional)

### Periodic Build

Configure **Build Triggers** → **Build periodically**

**Daily at 2 AM:**
```
H 2 * * *
```

**Every 6 hours:**
```
H */6 * * *
```

**Weekly on Sunday at 1 AM:**
```
H 1 * * 0
```

### Poll SCM (Git-based trigger)

If scripts are in Git:
```
H/15 * * * *  # Check every 15 minutes
```

---

## 🐛 Troubleshooting

### Issue 1: SSH Connection Failed

**Symptoms:** "Permission denied" or "Connection refused"

**Solutions:**
1. Verify SSH credentials:
   ```bash
   ssh <user>@<cloudera_host> "echo Connected"
   ```
2. Check Jenkins SSH plugin configuration
3. Verify firewall rules (port 22)

### Issue 2: Sqoop Command Not Found

**Symptoms:** "sqoop: command not found"

**Solutions:**
1. Add Hadoop/Sqoop to PATH in build script:
   ```bash
   export PATH=/usr/lib/sqoop/bin:$PATH
   export SQOOP_HOME=/usr/lib/sqoop
   ```
2. Or use full path:
   ```bash
   /usr/lib/sqoop/bin/sqoop import ...
   ```

### Issue 3: PostgreSQL Connection Failed

**Symptoms:** "Connection refused" or "FATAL: password authentication failed"

**Solutions:**
1. Verify cluster can reach PostgreSQL:
   ```bash
   ssh <user>@<cloudera_host>
   telnet 13.42.152.118 5432
   ```
2. Check pg_hba.conf on PostgreSQL server
3. Verify credentials in sqoop scripts

### Issue 4: HDFS Permission Denied

**Symptoms:** "Permission denied: user=<user>, access=WRITE"

**Solutions:**
1. Create directory with proper permissions:
   ```bash
   hdfs dfs -mkdir -p /tmp/uttam/tfl_data
   hdfs dfs -chown <user>:<group> /tmp/uttam/tfl_data
   hdfs dfs -chmod 755 /tmp/uttam/tfl_data
   ```

### Issue 5: Hive Database Permission Issues

**Symptoms:** "Authorization failed"

**Solutions:**
1. Check Hive warehouse permissions:
   ```bash
   hdfs dfs -chmod 777 /user/hive/warehouse
   ```
2. Or use user-specific location:
   ```sql
   CREATE DATABASE uttam_tfl
   LOCATION '/user/<username>/tfl_warehouse';
   ```

---

## 📊 Verification Commands

### On Cloudera Cluster

**Check HDFS:**
```bash
hdfs dfs -ls /tmp/uttam/tfl_data
hdfs dfs -ls /tmp/uttam/tfl_data/dim_stations
hdfs dfs -cat /tmp/uttam/tfl_data/dim_networks/part-m-00000 | head
```

**Check Hive:**
```bash
hive -e "SHOW DATABASES LIKE 'uttam_tfl';"
hive -e "USE uttam_tfl; SHOW TABLES;"
hive -e "USE uttam_tfl; SELECT COUNT(*) FROM dim_stations;"
```

**Query Hive Data:**
```bash
hive -e "
USE uttam_tfl;
SELECT s.station_name, SUM(f.total_entry_exit) AS total
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
GROUP BY s.station_name
ORDER BY total DESC
LIMIT 10;
"
```

---

## 📚 Additional Resources

### Jenkins Documentation
- SSH Agent Plugin: https://plugins.jenkins.io/ssh-agent/
- Publish Over SSH: https://plugins.jenkins.io/publish-over-ssh/

### Project Files
- Sqoop Scripts: `src/sqoop/`
- Hive Scripts: `src/hive/`
- GitHub: https://github.com/uttamraj9/TFL_Project_Demo

### Database Connection
- PostgreSQL: 13.42.152.118:5432/testdb
- Username: admin
- Password: admin123

---

## ✅ Success Checklist

Before running the pipeline, verify:

- [ ] Jenkins plugins installed (SSH Agent, Publish Over SSH)
- [ ] SSH credentials configured in Jenkins
- [ ] SSH connection to Cloudera cluster working
- [ ] Scripts copied to cluster (`~/TFL_Project_Demo/`)
- [ ] Scripts are executable (`chmod +x`)
- [ ] Hadoop/Sqoop/Hive available on cluster
- [ ] PostgreSQL accessible from cluster
- [ ] HDFS target directory writable
- [ ] Hive database permissions configured
- [ ] Jenkins project created with all build steps
- [ ] Parameters configured correctly
- [ ] Test build executed successfully

---

## 🎯 Expected Results

After successful execution:

**HDFS:**
```
/tmp/uttam/tfl_data/
  ├── dim_networks/ (1 record)
  ├── dim_lines/ (14 records)
  ├── dim_stations/ (436 records)
  ├── dim_date/ (15 records)
  ├── fact_station_lines/ (575 records)
  └── fact_passenger_entry_exit/ (4,771 records)
```

**Hive:**
```sql
USE uttam_tfl;
SHOW TABLES;
-- Output: 6 tables (dim_networks, dim_lines, dim_stations, dim_date, 
--                   fact_station_lines, fact_passenger_entry_exit)
```

**Console Output:**
```
✓ HDFS cleaned
✓ Sqoop import completed
✓ Hive database created
✓ Hive tables created
✓ TfL Data Pipeline: SUCCESS
```

---

*Last Updated: June 2, 2026*
*Version: 1.0*
*Jenkins Server: http://51.24.13.205:8081/*
