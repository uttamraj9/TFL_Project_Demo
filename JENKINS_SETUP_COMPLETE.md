# Complete Jenkins Setup for TfL Data Warehouse

**Status:** ✅ Everything cleaned - Ready for fresh Jenkins automation

---

## Current State (After Cleanup)

```
✅ Hive Database: uttam_tfl - DELETED
✅ HDFS: /user/uttam - DELETED
✅ HDFS: /tmp/uttam/tfl_data - DELETED
✅ Local files: Cleaned

Ready for Jenkins to create everything fresh!
```

---

## Step 1: Create Jenkins Pipeline Job

### Job Configuration:

1. **Open Jenkins:** http://13.42.152.118:8080 or http://51.24.13.205:8081
2. **Login:** consultant / WelcomeItc@2026
3. **Click:** "New Item"
4. **Enter name:** `TfL_Hive_Setup`
5. **Select:** "Pipeline"
6. **Click:** "OK"

### Pipeline Configuration:

**In the pipeline configuration page:**

1. **Description:**
   ```
   Automated Hive database and table creation for TfL Data Warehouse
   ```

2. **Build Triggers:** (Leave unchecked for manual runs)

3. **Pipeline Section:**
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** `https://github.com/uttamraj9/TFL_Project_Demo.git`
   - **Branch:** `*/main`
   - **Script Path:** `Jenkinsfile_Hive_Setup`

4. **Click:** "Save"

---

## Step 2: Run the Pipeline

1. **Go to job:** TfL_Hive_Setup
2. **Click:** "Build with Parameters"
3. **Select EXECUTION_MODE:**
   - `full_setup` - Creates database + all 6 tables
   - `database_only` - Creates only database
   - `tables_only` - Creates only tables (if database exists)

4. **Click:** "Build"

---

## What the Pipeline Will Do

### Stage 1: Checkout
```bash
✓ Clone GitHub repository
✓ Show latest commit
```

### Stage 2: Verify HQL Scripts
```bash
✓ Check src/hive/01_create_database.hql exists
✓ Check src/hive/02_create_tables.hql exists
✓ Show line counts
```

### Stage 3: Deploy HQL Scripts
```bash
✓ SCP scripts to Cloudera: /home/consultant/uttam/TFL_Project_Demo/src/hive/
✓ Set permissions
```

### Stage 4: Check HiveServer2
```bash
✓ Test connection: jdbc:hive2://ip-172-31-12-74:10000/default
✓ Run SHOW DATABASES to verify connectivity
```

### Stage 5: Execute HQL Scripts
```bash
✓ Run: beeline -f 01_create_database.hql
  - Creates: uttam_tfl database
  - Location: /user/hive/warehouse/uttam_tfl.db

✓ Run: beeline -f 02_create_tables.hql
  - Creates: 6 external tables
  - Points to: /tmp/uttam/tfl_data/
```

### Stage 6: Verify Results
```bash
✓ SHOW DATABASES LIKE 'uttam%'
✓ USE uttam_tfl; SHOW TABLES;
✓ Count rows in each table
```

---

## Expected Output

### Database Created:
```sql
| database_name  |
+----------------+
| uttam_tfl      |
+----------------+
```

### Tables Created:
```sql
| tab_name                   |
+----------------------------+
| dim_networks               |
| dim_lines                  |
| dim_stations               |
| dim_date                   |
| fact_station_lines         |
| fact_passenger_entry_exit  |
+----------------------------+
```

### Row Counts:
```
dim_networks: 1 rows
dim_lines: 14 rows
dim_stations: 436 rows
dim_date: 15 rows
fact_station_lines: 575 rows
fact_passenger_entry_exit: 4771 rows
```

---

## Troubleshooting

### Issue 1: HiveServer2 Connection Failed
```bash
Error: Could not open client transport
```
**Fix:**
1. Check Cloudera Manager: http://13.41.167.97:7180
2. Verify Hive on Tez service is running
3. Check HiveServer2 role on ip-172-31-12-74

### Issue 2: HDFS Data Not Found
```bash
Error: Path does not exist: /tmp/uttam/tfl_data/
```
**Fix:**
1. Data needs to be in HDFS first
2. Run Sqoop import job first OR
3. Use Jenkinsfile_Sqoop_Direct to load data

### Issue 3: Permission Denied
```bash
Permission denied: user=consultant
```
**Fix:**
1. Verify consultant user has HDFS access
2. Check HDFS permissions: `hdfs dfs -ls /tmp/uttam/`

---

## Verification Steps (After Jenkins Run)

### Check via Hue (Web UI):
1. Go to: http://13.41.167.97:8888
2. Login: admin / Admin@2026
3. Click: Editor → Hive
4. Run:
   ```sql
   SHOW DATABASES;
   USE uttam_tfl;
   SHOW TABLES;
   SELECT COUNT(*) FROM dim_networks;
   ```

### Check via Beeline (Command Line):
```bash
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97

beeline -u 'jdbc:hive2://ip-172-31-12-74.eu-west-2.compute.internal:10000/uttam_tfl'

# Inside beeline:
SHOW TABLES;
SELECT * FROM dim_networks;
```

### Check HDFS:
```bash
hdfs dfs -ls /user/hive/warehouse/uttam_tfl.db/
hdfs dfs -ls /tmp/uttam/tfl_data/
```

---

## Complete Workflow

```
1. Jenkins: TfL_Hive_Setup (full_setup)
   ↓
2. Creates: Database + 6 Tables
   ↓
3. Verify in Hue: Query tables
   ↓
4. Success! ✅
```

---

## Files Used by Jenkins

```
Repository: github.com/uttamraj9/TFL_Project_Demo
├── Jenkinsfile_Hive_Setup        (Pipeline definition)
├── src/hive/
│   ├── 01_create_database.hql    (CREATE DATABASE)
│   └── 02_create_tables.hql      (CREATE EXTERNAL TABLES x6)
```

---

## Connection Details

| Component | Host/URL | Port | User | Password |
|-----------|----------|------|------|----------|
| HiveServer2 | ip-172-31-12-74.eu-west-2.compute.internal | 10000 | - | - |
| Hue | http://13.41.167.97:8888 | 8888 | admin | Admin@2026 |
| Cloudera Manager | http://13.41.167.97:7180 | 7180 | admin | Admin@2026 |
| Jenkins | http://13.42.152.118:8080 | 8080 | consultant | WelcomeItc@2026 |

---

## Success Criteria

✅ Jenkins pipeline shows "SUCCESS"  
✅ Database `uttam_tfl` exists  
✅ 6 tables created  
✅ All tables have data (row count > 0)  
✅ Can query tables in Hue  

---

**Ready to run!** Create the Jenkins job and build with `EXECUTION_MODE=full_setup`
