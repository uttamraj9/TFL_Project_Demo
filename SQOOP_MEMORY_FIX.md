# Sqoop Memory Error - Fix Guide

## 🚨 Problem

```
There is insufficient memory for the Java Runtime Environment to continue.
Native memory allocation (mmap) failed to map 353370112 bytes (337 MB)
Error: Cannot allocate memory (errno=12)
```

**Job:** PG_to_HDFS_Sqoop_Uttam (Build #9)  
**Error File:** `/home/consultant/uttam/TFL_Project_Demo/hs_err_pid3660973.log`

---

## 🔍 Root Cause

Sqoop is trying to allocate **337 MB** of heap memory, but the system cannot provide it. This happens when:

1. **System Memory Exhausted** - Other processes consuming RAM
2. **Java Heap Too Large** - Default JVM settings too aggressive
3. **Concurrent Jobs** - Multiple Sqoop/MapReduce jobs running
4. **Memory Fragmentation** - Available but not contiguous

---

## ✅ Solution 1: Reduce Sqoop Memory (Recommended)

### Step 1: Check Current Memory Settings

```bash
# SSH to Cloudera
ssh consultant@13.41.167.97

# Check available memory
free -h

# Check running Java processes
ps aux | grep -E 'sqoop|mapreduce' | head -20
```

### Step 2: Set JAVA_HEAP_MAX for Sqoop

Add to your Jenkins script **BEFORE** running Sqoop:

```bash
# Set lower heap size for Sqoop (128M instead of default 337M)
export HADOOP_CLIENT_OPTS="-Xmx128m"

# Or more explicitly:
export SQOOP_CLIENT_HEAP_MAX="128"

# Then run Sqoop
sqoop import \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb' \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /user/hadoop/tfl/dim_stations \
  --m 1
```

### Step 3: Update Jenkinsfile

Edit your Sqoop job's Execute Shell step:

```bash
#!/bin/bash

# ADD THESE LINES AT THE TOP:
export HADOOP_CLIENT_OPTS="-Xmx128m"
export MAPRED_CHILD_JAVA_OPTS="-Xmx512m"

# Then your existing Sqoop commands:
sshpass -p "${REMOTE_PASSWORD}" ssh ${REMOTE_USER}@${REMOTE_HOST} \
  "export HADOOP_CLIENT_OPTS='-Xmx128m' && \
   sqoop import --connect ... --table dim_stations ..."
```

---

## ✅ Solution 2: Reduce MapReduce Mapper Memory

Sqoop launches MapReduce tasks. Reduce mapper memory allocation:

```bash
sqoop import \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb' \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /user/hadoop/tfl/dim_stations \
  --m 1 \
  -D mapreduce.map.memory.mb=256 \
  -D mapreduce.map.java.opts="-Xmx204m"
```

**Explanation:**
- `mapreduce.map.memory.mb=256` - Container memory (256 MB)
- `mapreduce.map.java.opts="-Xmx204m"` - JVM heap (80% of container)

---

## ✅ Solution 3: Use Single Mapper (Already Done)

You're already using `--m 1` (single mapper), which is good. But ensure only ONE Sqoop job runs at a time:

```bash
# In Jenkins, check for running Sqoop jobs BEFORE starting new one
sshpass -p "${REMOTE_PASSWORD}" ssh ${REMOTE_USER}@${REMOTE_HOST} \
  "ps aux | grep sqoop | grep -v grep && echo 'Sqoop already running! Exiting.' && exit 1 || echo 'No Sqoop running. Proceeding...'"

# Then run Sqoop
sshpass -p "${REMOTE_PASSWORD}" ssh ${REMOTE_USER}@${REMOTE_HOST} \
  "export HADOOP_CLIENT_OPTS='-Xmx128m' && sqoop import ..."
```

---

## ✅ Solution 4: Check System Memory

### Check Available Memory on Cloudera

```bash
ssh consultant@13.41.167.97

# Total memory and usage
free -h

# Expected output:
#               total        used        free      shared  buff/cache   available
# Mem:          15Gi        8.0Gi       2.0Gi       100Mi       5.0Gi       6.5Gi
# Swap:         8.0Gi       1.0Gi       7.0Gi

# If 'available' < 500M, you have a memory issue
```

### Kill Stale Jobs

```bash
# Find stale MapReduce/Sqoop processes
ps aux | grep -E 'sqoop|mapreduce|DataStreamer' | grep consultant

# Kill them (use PID from above)
kill -9 <PID>

# Or kill all Sqoop processes (CAUTION!)
pkill -9 -f sqoop
```

### Check YARN Memory

```bash
# Check NodeManager memory allocation
yarn node -list

# Check running applications
yarn application -list

# Kill stuck applications
yarn application -kill <application_id>
```

---

## ✅ Solution 5: Incremental Table Import

Instead of importing all 6 tables at once, import them **sequentially with delays**:

### Jenkins Pipeline Approach

```groovy
stage('Sqoop Import') {
    steps {
        script {
            def tables = ['dim_networks', 'dim_lines', 'dim_date', 'dim_stations', 
                          'fact_station_lines', 'fact_passenger_entry_exit']
            
            tables.each { table ->
                echo "Importing ${table}..."
                
                sh """
                    sshpass -p "${REMOTE_PASSWORD}" ssh ${REMOTE_USER}@${REMOTE_HOST} \
                    "export HADOOP_CLIENT_OPTS='-Xmx128m' && \
                     sqoop import \
                       --connect 'jdbc:postgresql://13.42.152.118:5432/testdb' \
                       --username admin \
                       --password admin123 \
                       --table ${table} \
                       --target-dir /user/hadoop/tfl/${table} \
                       --m 1 \
                       -D mapreduce.map.memory.mb=256 \
                       -D mapreduce.map.java.opts='-Xmx204m' \
                       --delete-target-dir"
                """
                
                // Wait 10 seconds between tables
                sleep(10)
                
                echo "✓ ${table} imported successfully"
            }
        }
    }
}
```

---

## ✅ Solution 6: Restart NodeManager (Last Resort)

If memory is truly exhausted:

```bash
# SSH to Cloudera
ssh consultant@13.41.167.97

# Restart YARN NodeManager (as root or with sudo)
sudo systemctl restart hadoop-yarn-nodemanager

# Or via Cloudera Manager:
# 1. Go to http://13.41.167.97:7180/
# 2. Clusters > Cluster 1 > YARN
# 3. Actions > Restart NodeManager
```

---

## 🔧 Complete Fixed Jenkins Script

Replace your Sqoop job's Execute Shell with this:

```bash
#!/bin/bash
set -e

# Configuration
REMOTE_HOST="13.42.152.118"
REMOTE_USER="admin"
REMOTE_PASSWORD="admin123"
CLOUDERA_HOST="13.41.167.97"
CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"

echo "========================================"
echo "TfL PostgreSQL to HDFS Sqoop Pipeline"
echo "========================================"

# Step 1: Check memory on Cloudera
echo "Step 1: Checking Cloudera memory..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no \
    $CLOUDERA_USER@$CLOUDERA_HOST "free -h | grep 'Mem:'"

# Step 2: Kill stale Sqoop jobs
echo "Step 2: Cleaning stale jobs..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no \
    $CLOUDERA_USER@$CLOUDERA_HOST "pkill -9 -f 'sqoop.*testdb' || true"

sleep 5

# Step 3: Import tables ONE BY ONE
echo "Step 3: Starting Sqoop imports..."

TABLES=("dim_networks" "dim_lines" "dim_date" "dim_stations" "fact_station_lines" "fact_passenger_entry_exit")

for TABLE in "${TABLES[@]}"; do
    echo "========================================"
    echo "Importing: $TABLE"
    echo "========================================"
    
    sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no \
        $CLOUDERA_USER@$CLOUDERA_HOST \
        "export HADOOP_CLIENT_OPTS='-Xmx128m' && \
         sqoop import \
           --connect 'jdbc:postgresql://$REMOTE_HOST:5432/testdb' \
           --username $REMOTE_USER \
           --password $REMOTE_PASSWORD \
           --table $TABLE \
           --target-dir /user/$CLOUDERA_USER/tfl/$TABLE \
           --m 1 \
           -D mapreduce.map.memory.mb=256 \
           -D mapreduce.map.java.opts='-Xmx204m' \
           --delete-target-dir"
    
    echo "✓ $TABLE imported successfully"
    
    # Wait 10 seconds before next table
    echo "Waiting 10 seconds before next import..."
    sleep 10
done

# Step 4: Verify all tables
echo "========================================"
echo "Step 4: Verifying HDFS imports..."
echo "========================================"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "hdfs dfs -ls /user/$CLOUDERA_USER/tfl/"

echo "========================================"
echo "✓✓✓ ALL TABLES IMPORTED SUCCESSFULLY ✓✓✓"
echo "========================================"
```

---

## 📊 Memory Sizing Reference

### Recommended Settings by System Memory

**System has 8 GB RAM:**
```bash
export HADOOP_CLIENT_OPTS="-Xmx64m"
-D mapreduce.map.memory.mb=256
-D mapreduce.map.java.opts="-Xmx204m"
```

**System has 16 GB RAM:**
```bash
export HADOOP_CLIENT_OPTS="-Xmx128m"
-D mapreduce.map.memory.mb=512
-D mapreduce.map.java.opts="-Xmx409m"
```

**System has 32 GB+ RAM:**
```bash
export HADOOP_CLIENT_OPTS="-Xmx256m"
-D mapreduce.map.memory.mb=1024
-D mapreduce.map.java.opts="-Xmx819m"
```

---

## 🧪 Test Before Running Full Pipeline

Test with ONE small table first:

```bash
ssh consultant@13.41.167.97

# Test with smallest table (dim_networks)
export HADOOP_CLIENT_OPTS="-Xmx128m"

sqoop import \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb' \
  --username admin \
  --password admin123 \
  --table dim_networks \
  --target-dir /user/consultant/tfl_test/dim_networks \
  --m 1 \
  -D mapreduce.map.memory.mb=256 \
  -D mapreduce.map.java.opts="-Xmx204m" \
  --delete-target-dir

# If this succeeds, proceed with full pipeline
```

---

## ✅ Quick Fix Checklist

Before running Sqoop job again:

- [ ] Add `export HADOOP_CLIENT_OPTS="-Xmx128m"` to Jenkins script
- [ ] Add `-D mapreduce.map.memory.mb=256` to Sqoop command
- [ ] Add `-D mapreduce.map.java.opts="-Xmx204m"` to Sqoop command
- [ ] Import tables sequentially (not in parallel)
- [ ] Add `sleep 10` between table imports
- [ ] Check `free -h` on Cloudera shows > 500M available
- [ ] Kill any stale Sqoop processes before starting
- [ ] Use `--m 1` (single mapper) - already doing this ✓

---

## 🎯 Expected Result After Fix

```
======================================
Importing: dim_networks
======================================
✓ dim_networks imported successfully
Waiting 10 seconds before next import...

======================================
Importing: dim_lines
======================================
✓ dim_lines imported successfully
Waiting 10 seconds before next import...

[... continues for all 6 tables ...]

======================================
✓✓✓ ALL TABLES IMPORTED SUCCESSFULLY ✓✓✓
======================================
```

---

## 📚 Related Documentation

- **Sqoop Memory Tuning:** https://sqoop.apache.org/docs/1.4.7/SqoopUserGuide.html#_controlling_memory_usage
- **YARN Memory Configuration:** https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceModel.html
- **MapReduce Memory Settings:** https://hadoop.apache.org/docs/stable/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html#Job_Configuration

---

**Issue:** Java OOM (Out of Memory) - 337 MB allocation failed  
**Fix:** Reduce heap to 128 MB + sequential imports  
**Status:** Ready to retry with reduced memory settings  
**Created:** June 2, 2026
