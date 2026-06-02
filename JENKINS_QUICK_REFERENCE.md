# Jenkins TfL Pipeline - Quick Reference Card

## 🔗 Jenkins Server
**URL:** http://51.24.13.205:8081/

---

## 📋 Required Jenkins Configuration

### 1. Plugins to Install
```
Manage Jenkins → Manage Plugins → Available
```
- SSH Agent Plugin
- Publish Over SSH Plugin
- AnsiColor Plugin (optional - for colored output)

---

### 2. SSH Credentials Setup
```
Manage Jenkins → Manage Credentials → (global) → Add Credentials
```

**Configuration:**
```
Kind: SSH Username with private key
ID: cloudera-cluster-ssh
Description: Cloudera Cluster SSH Access
Username: <your_cloudera_username>
Private Key: [Select "Enter directly" and paste your SSH private key]
```

---

### 3. SSH Server Configuration
```
Manage Jenkins → Configure System → SSH remote hosts
```

**Configuration:**
```
Hostname: <cloudera_edge_node_hostname_or_ip>
Port: 22
Credentials: cloudera-cluster-ssh
```
Click **Check connection** to verify → Should show ✓ Success

---

## 🚀 Freestyle Project Configuration

### Project Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `PROJECT_DIR` | String | `/home/<user>/TFL_Project_Demo` | Project location on cluster |
| `HDFS_TARGET` | String | `/tmp/uttam/tfl_data` | HDFS destination path |
| `STEP` | Choice | `ALL` | ALL / SQOOP_ONLY / HIVE_ONLY |
| `CLEAN_HDFS` | Boolean | `true` | Delete existing HDFS data |

---

## 📝 Build Steps (SSH Execute)

### Step 1: Clean HDFS
```bash
if [ "$CLEAN_HDFS" = "true" ]; then
    hdfs dfs -rm -r -f -skipTrash $HDFS_TARGET || true
fi
```

### Step 2: Run Sqoop
```bash
cd $PROJECT_DIR
bash src/sqoop/import_all_tables.sh
```

### Step 3: Create Hive Database
```bash
cd $PROJECT_DIR
hive -f src/hive/create_database.hql
```

### Step 4: Create Hive Tables
```bash
cd $PROJECT_DIR
hive -f src/hive/create_tables.hql
```

---

## 🎯 One-Line Build (Alternative)

Instead of 4 separate build steps, use one:

```bash
cd /home/<user>/TFL_Project_Demo && ./run_pipeline.sh all
```

---

## 🧪 Testing Commands

### Test SSH Connection
```bash
# On Jenkins build step
whoami
hostname
hdfs version
hive --version
```

### Verify Sqoop
```bash
sqoop version
```

### Check HDFS Access
```bash
hdfs dfs -ls /tmp
hdfs dfs -mkdir -p /tmp/uttam/tfl_data
```

---

## 🐛 Common Issues & Fixes

### Issue: "sqoop: command not found"
**Fix:**
```bash
export PATH=/usr/lib/sqoop/bin:$PATH
export SQOOP_HOME=/usr/lib/sqoop
```

### Issue: "HDFS permission denied"
**Fix:**
```bash
hdfs dfs -mkdir -p /tmp/uttam/tfl_data
hdfs dfs -chmod 755 /tmp/uttam/tfl_data
```

### Issue: "PostgreSQL connection refused"
**Fix:** Check firewall from cluster:
```bash
telnet 13.42.152.118 5432
```

---

## ✅ Success Indicators

**Console Output Should Show:**
```
✓ Sqoop import completed (6 tables)
✓ Hive database created (uttam_tfl)
✓ Hive tables created (6 tables)
✓ Record counts verified
✓ Pipeline SUCCESS
```

**Expected Records:**
- dim_networks: 1
- dim_lines: 14
- dim_stations: 436
- dim_date: 15
- fact_station_lines: 575
- fact_passenger_entry_exit: 4,771

---

## 📅 Scheduling (Optional)

### Daily at 2 AM
```
H 2 * * *
```

### Every 6 hours
```
H */6 * * *
```

### Weekly on Sunday
```
H 1 * * 0
```

---

## 🔍 Verification Commands

### Check HDFS
```bash
hdfs dfs -ls /tmp/uttam/tfl_data
hdfs dfs -count /tmp/uttam/tfl_data/*
```

### Check Hive
```bash
hive -e "USE uttam_tfl; SHOW TABLES;"
hive -e "USE uttam_tfl; SELECT COUNT(*) FROM dim_stations;"
```

### Query Top Stations
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

## 📞 Resources

**Full Documentation:** See `JENKINS_SETUP.md`

**Database Connection:**
- Host: 13.42.152.118:5432
- Database: testdb
- User: admin / admin123

**Project Repository:**
- https://github.com/uttamraj9/TFL_Project_Demo

**Scripts Location on Cluster:**
- Sqoop: `~/TFL_Project_Demo/src/sqoop/`
- Hive: `~/TFL_Project_Demo/src/hive/`

---

*Quick Reference v1.0 - June 2, 2026*
