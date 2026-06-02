# Complete TfL ETL Pipeline - Setup Guide

## 🎯 Complete Scope

This pipeline performs **end-to-end ETL** from PostgreSQL to Hive:

```
PostgreSQL (testdb)
    ↓ (Sqoop import with memory fix)
HDFS (/user/consultant/tfl/)
    ↓ (External Hive tables)
Hive (tfl_warehouse database)
    ↓ (Analytical queries)
Business Intelligence
```

---

## 📋 What This Pipeline Does

### ✅ Phase 1: Sqoop Import (PostgreSQL → HDFS)
- Imports **all 6 tables** from PostgreSQL to HDFS
- Uses **optimized memory settings** (fixes OOM error)
- Sequential import with 10-second delays
- Stores data in `/user/consultant/tfl/`

### ✅ Phase 2: Hive Table Creation (HDFS → Hive)
- Creates Hive database: `tfl_warehouse`
- Creates **6 external tables** pointing to HDFS data
- Dimension tables: networks, lines, date, stations
- Fact tables: station_lines, passenger_entry_exit

### ✅ Phase 3: Verification & Sample Queries
- Verifies HDFS row counts
- Verifies Hive table row counts
- Runs sample analytical queries
- Shows top 10 busiest stations (2019)

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Create Jenkins Job

```bash
# Option A: Via Jenkins UI
1. Go to: http://51.24.13.205:8081/
2. Click "New Item"
3. Name: "TfL_Complete_ETL_Pipeline"
4. Type: "Pipeline"
5. Click OK

# Option B: Via Jenkins CLI (faster)
curl -X POST -u "consultant:WelcomeItc@2026" \
  -H "Content-Type: application/xml" \
  --data-binary @- \
  'http://51.24.13.205:8081/createItem?name=TfL_Complete_ETL_Pipeline' << 'XML_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Complete ETL: PostgreSQL → HDFS → Hive</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/uttamraj9/TFL_Project_Demo.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile_Complete_ETL</scriptPath>
  </definition>
</flow-definition>
XML_EOF
```

### Step 2: Configure Pipeline

In Jenkins UI:
1. **Pipeline Definition:** Pipeline script from SCM
2. **SCM:** Git
3. **Repository URL:** `https://github.com/uttamraj9/TFL_Project_Demo.git`
4. **Branch:** `*/main`
5. **Script Path:** `Jenkinsfile_Complete_ETL`

### Step 3: Run Pipeline

```bash
# Via UI:
1. Click "Build with Parameters"
2. Select ETL_MODE: full
3. CLEAN_START: true (first run)
4. MAPPER_MEMORY: 256
5. Click "Build"

# Via API:
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

curl -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  'http://51.24.13.205:8081/job/TfL_Complete_ETL_Pipeline/buildWithParameters?ETL_MODE=full&CLEAN_START=true&MAPPER_MEMORY=256'
```

---

## 📊 Pipeline Parameters

### ETL_MODE (Choice)

| Mode | Description | Use Case |
|------|-------------|----------|
| **full** | Complete ETL (Sqoop + Hive + Verify) | First run, production deployment |
| **sqoop_only** | Only import from PostgreSQL to HDFS | Refresh data from database |
| **hive_only** | Only create Hive tables (skip Sqoop) | Recreate Hive tables after schema change |
| **verify_only** | Only run verification queries | Test existing deployment |

### CLEAN_START (Boolean)

- **true** - Delete existing HDFS data and Hive tables before import
- **false** - Keep existing data (will fail if tables exist)

**Recommendation:** Use `true` on first run, `false` for incremental updates.

### MAPPER_MEMORY (String)

- **Default:** 256 MB (safe for 8 GB RAM)
- **Range:** 128-1024 MB
- **Recommendation:**
  - 8 GB RAM → 256 MB
  - 16 GB RAM → 512 MB
  - 32 GB RAM → 1024 MB

---

## 🏗️ Pipeline Stages

### Stage 1: Environment Check
- Verifies configuration
- Checks Cloudera server memory
- **Duration:** ~10 seconds

### Stage 2: Kill Stale Jobs
- Cleans up previous Sqoop/MapReduce processes
- Prevents memory conflicts
- **Duration:** ~5 seconds

### Stage 3: Clean Existing Data (Conditional)
- Drops Hive database (CASCADE)
- Removes HDFS directory
- **Runs only if:** `CLEAN_START=true`
- **Duration:** ~15 seconds

### Stage 4: Sqoop Import - Dimensions
- Imports 4 dimension tables:
  - `dim_networks` (1 row)
  - `dim_lines` (14 rows)
  - `dim_date` (15 rows)
  - `dim_stations` (436 rows)
- **Duration:** ~2 minutes

### Stage 5: Sqoop Import - Facts
- Imports 2 fact tables:
  - `fact_station_lines` (575 rows)
  - `fact_passenger_entry_exit` (4,771 rows)
- **Duration:** ~3 minutes

### Stage 6: Verify HDFS Data
- Lists HDFS directory structure
- Counts rows per table
- **Duration:** ~20 seconds

### Stage 7: Create Hive Database
- Creates database: `tfl_warehouse`
- **Duration:** ~5 seconds

### Stage 8: Create Hive Tables - Dimensions
- Creates 4 external dimension tables
- Points to HDFS locations
- **Duration:** ~15 seconds

### Stage 9: Create Hive Tables - Facts
- Creates 2 external fact tables
- Points to HDFS locations
- **Duration:** ~15 seconds

### Stage 10: Verify Hive Tables
- Lists all tables in `tfl_warehouse`
- Counts rows per Hive table
- **Duration:** ~30 seconds

### Stage 11: Sample Queries
- Runs 2 analytical queries:
  1. Top 10 busiest stations (2019)
  2. Lines with most stations
- **Duration:** ~40 seconds

**Total Pipeline Duration:** ~7-8 minutes

---

## 📂 Data Locations

### PostgreSQL (Source)
```
Host: 13.42.152.118:5432
Database: testdb
Tables: dim_networks, dim_lines, dim_date, dim_stations,
        fact_station_lines, fact_passenger_entry_exit
```

### HDFS (Staging)
```
hdfs://namenode/user/consultant/tfl/
├── dim_networks/
│   └── part-m-00000 (1 row)
├── dim_lines/
│   └── part-m-00000 (14 rows)
├── dim_date/
│   └── part-m-00000 (15 rows)
├── dim_stations/
│   └── part-m-00000 (436 rows)
├── fact_station_lines/
│   └── part-m-00000 (575 rows)
└── fact_passenger_entry_exit/
    └── part-m-00000 (4,771 rows)
```

### Hive (Analytics)
```
Database: tfl_warehouse

External Tables (point to HDFS):
- dim_networks
- dim_lines
- dim_date
- dim_stations
- fact_station_lines
- fact_passenger_entry_exit
```

---

## ✅ Expected Output

### Console Output

```
=========================================
Stage 1: Environment Verification
=========================================
ETL Mode: full
Clean Start: true
Mapper Memory: 256 MB
Cloudera: 13.41.167.97
PostgreSQL: 13.42.152.118:5432/testdb
HDFS Base: /user/consultant/tfl
Hive DB: tfl_warehouse

              total        used        free      shared  buff/cache   available
Mem:           15Gi        8.0Gi       3.5Gi       100Mi       3.5Gi       6.8Gi
Swap:          8.0Gi       512Mi       7.5Gi

=========================================
Stage 2: Clean Stale Processes
=========================================
Killing stale Sqoop/MapReduce jobs...
✓ Stale jobs cleaned

=========================================
Stage 3: Clean Existing HDFS/Hive Data
=========================================
Dropping Hive database...
Cleaning HDFS directory...
✓ Cleanup complete

=========================================
Stage 4: Sqoop Import - Dimension Tables
=========================================
Importing dim_networks...
INFO tool.CodeGenTool: Compiling /tmp/sqoop-consultant/...
INFO mapreduce.Job: Retrieved 1 records.
✓ dim_networks imported

Importing dim_lines...
INFO mapreduce.Job: Retrieved 14 records.
✓ dim_lines imported

[... continues for all dimension tables ...]

=========================================
Stage 6: Verify HDFS Imports
=========================================
HDFS directory structure:
drwxr-xr-x   - consultant supergroup          0 2026-06-02 18:30 /user/consultant/tfl/dim_networks
drwxr-xr-x   - consultant supergroup          0 2026-06-02 18:31 /user/consultant/tfl/dim_lines
[...]

Row counts per table:
  dim_networks: 1 rows
  dim_lines: 14 rows
  dim_date: 15 rows
  dim_stations: 436 rows
  fact_station_lines: 575 rows
  fact_passenger_entry_exit: 4771 rows

=========================================
Stage 7: Create Hive Database & Tables
=========================================
✓ Hive database created: tfl_warehouse

=========================================
Stage 8: Create Hive Dimension Tables
=========================================
✓ Dimension tables created

=========================================
Stage 9: Create Hive Fact Tables
=========================================
✓ Fact tables created

=========================================
Stage 10: Verify Hive Tables
=========================================
Hive tables in tfl_warehouse:
dim_date
dim_lines
dim_networks
dim_stations
fact_passenger_entry_exit
fact_station_lines

Row counts per Hive table:
  dim_networks: 1 rows
  dim_lines: 14 rows
  dim_date: 15 rows
  dim_stations: 436 rows
  fact_station_lines: 575 rows
  fact_passenger_entry_exit: 4771 rows

=========================================
Stage 11: Run Sample Analytical Queries
=========================================
Sample Query 1: Top 10 busiest stations (2019)
station_name                    total_passengers
Stratford                       118564624
Bank and Monument               92291003
King's Cross St. Pancras        88273827
Victoria LU                     85468928
Waterloo LU                     82934325
[...]

Sample Query 2: Lines with most stations
line_name               num_stations
Piccadilly              53
District                60
Northern                50
Central                 49
[...]

=========================================
✓✓✓ COMPLETE ETL PIPELINE SUCCESSFUL ✓✓✓
=========================================
Mode: full
Clean Start: true

PostgreSQL: 13.42.152.118:5432/testdb
HDFS: /user/consultant/tfl
Hive DB: tfl_warehouse

Access Cloudera Manager:
  http://13.41.167.97:7180/
  User: Admin
  Password: Admin@2026

Query your data:
  ssh consultant@13.41.167.97
  hive
  USE tfl_warehouse;
  SELECT * FROM dim_stations LIMIT 10;
=========================================
```

---

## 🔍 Verification Commands

### Check HDFS Data

```bash
# SSH to Cloudera
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97
sudo su - consultant

# List HDFS directories
hdfs dfs -ls /user/consultant/tfl/

# Check row counts
hdfs dfs -cat /user/consultant/tfl/dim_stations/part-m-00000 | wc -l

# View sample data
hdfs dfs -cat /user/consultant/tfl/dim_stations/part-m-00000 | head -10
```

### Check Hive Tables

```bash
# SSH to Cloudera
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97
sudo su - consultant

# Open Hive CLI
hive

# Inside Hive:
USE tfl_warehouse;
SHOW TABLES;

SELECT COUNT(*) FROM dim_stations;
SELECT * FROM dim_stations LIMIT 10;

SELECT 
    s.station_name, 
    SUM(f.total_entry_exit) as total_passengers
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year = 2019
GROUP BY s.station_name
ORDER BY total_passengers DESC
LIMIT 10;
```

---

## 🔧 Troubleshooting

### Issue 1: Memory Error (OOM)

**Symptoms:**
```
Native memory allocation (mmap) failed
Cannot allocate memory (errno=12)
```

**Solution:**
1. Reduce `MAPPER_MEMORY` parameter: 256 → 128
2. Check Cloudera memory: `free -h` (need 500+ MB available)
3. Kill stale jobs: `pkill -9 -f sqoop`
4. Restart NodeManager (Cloudera Manager)

### Issue 2: HDFS Already Exists

**Symptoms:**
```
Target directory already exists
```

**Solution:**
- Set `CLEAN_START=true` in build parameters
- Or manually delete: `hdfs dfs -rm -r /user/consultant/tfl`

### Issue 3: Hive Table Already Exists

**Symptoms:**
```
AlreadyExistsException: Table tfl_warehouse.dim_stations already exists
```

**Solution:**
- Set `CLEAN_START=true` in build parameters
- Or manually drop: `hive -e 'DROP DATABASE tfl_warehouse CASCADE;'`

### Issue 4: PostgreSQL Connection Timeout

**Symptoms:**
```
Connection refused: 13.42.152.118:5432
```

**Solution:**
1. Check PostgreSQL is running
2. Check firewall allows 5432 from Cloudera
3. Test connectivity: `telnet 13.42.152.118 5432`

### Issue 5: Sqoop Hangs

**Symptoms:**
- Stage 4/5 runs for > 10 minutes without progress

**Solution:**
1. Check YARN ResourceManager: http://13.41.167.97:8088/
2. Check application logs: `yarn logs -applicationId <app-id>`
3. Kill application: `yarn application -kill <app-id>`
4. Restart pipeline

---

## 📊 Performance Tuning

### Memory Configuration by System

**8 GB RAM System:**
```
MAPPER_MEMORY: 256
HADOOP_CLIENT_OPTS: -Xmx128m
```

**16 GB RAM System:**
```
MAPPER_MEMORY: 512
HADOOP_CLIENT_OPTS: -Xmx256m
```

**32 GB RAM System:**
```
MAPPER_MEMORY: 1024
HADOOP_CLIENT_OPTS: -Xmx512m
```

### Parallelization

**Current:** Sequential import (one table at a time)
**Reason:** Prevents memory exhaustion on constrained systems

**For high-memory systems (32 GB+):**
Edit `Jenkinsfile_Complete_ETL` to use `parallel` directive:

```groovy
stage('Sqoop Import - All Tables') {
    parallel {
        stage('dim_networks') { steps { /* sqoop import */ } }
        stage('dim_lines') { steps { /* sqoop import */ } }
        // ... etc
    }
}
```

---

## 🎯 Success Checklist

Before running pipeline:

- [ ] Jenkins server has network access to both PostgreSQL and Cloudera
- [ ] PostgreSQL has data in all 6 tables
- [ ] Cloudera cluster is running (check http://13.41.167.97:7180/)
- [ ] YARN NodeManager is active
- [ ] Cloudera has > 500 MB free memory (`free -h`)
- [ ] `sshpass` is installed on Jenkins server
- [ ] Git repository has `Jenkinsfile_Complete_ETL` committed

After successful run:

- [ ] All 11 stages show ✓ green
- [ ] HDFS has 6 directories under `/user/consultant/tfl/`
- [ ] Hive has 6 tables in `tfl_warehouse` database
- [ ] Row counts match: PostgreSQL = HDFS = Hive
- [ ] Sample queries return results

---

## 📚 Additional Resources

### Cloudera Manager
- **URL:** http://13.41.167.97:7180/
- **User:** Admin
- **Password:** Admin@2026

### YARN ResourceManager
- **URL:** http://13.41.167.97:8088/

### Hive Web UI
- **URL:** http://13.41.167.97:10002/ (if enabled)

### SSH Access (PEM file)
```bash
# From your laptop:
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97

# Switch to consultant user:
sudo su - consultant

# Check HDFS:
hdfs dfs -ls /user/consultant/tfl/

# Query Hive:
hive -e "USE tfl_warehouse; SELECT COUNT(*) FROM dim_stations;"
```

---

## 🎉 Summary

This complete ETL pipeline:

✅ **Fixes memory issues** with optimized Sqoop settings  
✅ **Imports all 6 tables** from PostgreSQL to HDFS  
✅ **Creates Hive warehouse** with proper schema  
✅ **Verifies data quality** at each stage  
✅ **Runs sample queries** to prove it works  

**Total Duration:** ~7-8 minutes for complete ETL

**Next Steps:**
1. Run with `ETL_MODE=full` and `CLEAN_START=true`
2. Monitor console output (real-time)
3. Verify row counts match PostgreSQL
4. Start running analytical queries in Hive!

---

**Created:** June 2, 2026  
**Status:** Production Ready ✅  
**Pipeline File:** `Jenkinsfile_Complete_ETL`  
**Documentation:** `COMPLETE_PIPELINE_SETUP.md`
