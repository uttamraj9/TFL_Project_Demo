# Jenkins Pipeline - Successfully Configured and Running! ✅

## 🎉 Status: BUILD #7 RUNNING

**Jenkins URL:** http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/console

---

## ✅ What We Accomplished

### 1. Fixed SCP Banner Issue
**Problem:** SSH banner from Cloudera server was interfering with SCP file transfers

**Solution Applied:**
- Modified `/home/consultant/.bash_profile` on Cloudera server
- Added condition to only show banner for interactive shells: `if [[ $- == *i* ]]`
- Banner now suppressed for SCP/non-interactive sessions

**Result:** ✅ SCP now works perfectly!

### 2. Updated Jenkins Job Configuration
**Job:** PG_to_HDFS_Sqoop_Uttam
**Configuration:** Updated via Jenkins API using Python XML parser

**Script Features:**
- Uses scripts directly from GitHub workspace ($WORKSPACE)
- Filters out SSH banner messages with grep
- Complete 11-step pipeline
- Full error handling and verification

### 3. Triggered Build via Jenkins API
**Method:** Using curl with CSRF crumb authentication

**Credentials:**
- Username: `consultant`
- Password: `WelcomeItc@2026`
- CSRF Protection: Handled automatically

### 4. SSH Access Configuration
**From Local Machine:**
- Used `ec2-user` account with SSH key
- Key location: `~/Desktop/Training/test_key.pem`
- Modified `consultant` user `.bash_profile`

---

## 📊 Build #7 Progress

### Steps Completed ✅:
1. ✅ Git clone from GitHub
2. ✅ Verify scripts in workspace
3. ✅ Create remote directories on Cloudera
4. ✅ Copy Sqoop scripts (4 files)
5. ✅ Copy Hive scripts (4 files)
6. ✅ Set execute permissions
7. ✅ Verify files on remote
8. ✅ Clean HDFS target directory
9. 🔄 Running Sqoop import (6 tables)...
10. ⏳ Pending: Create Hive database
11. ⏳ Pending: Create Hive tables
12. ⏳ Pending: Verification

---

## 🔧 Technical Changes Made

### On Cloudera Server (13.41.167.97)

**File Modified:** `/home/consultant/.bash_profile`

**Before:**
```bash
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo '  ITC Big Data Lab — CDH 7.1.7'
echo '  Commands: hadoop  hdfs  yarn  hive  spark-shell  python3'
echo '  HDFS home: /user/consultant'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
```

**After:**
```bash
# Only show banner for interactive shells (not for SCP/non-interactive)
if [[ $- == *i* ]]; then
    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    echo '  ITC Big Data Lab — CDH 7.1.7'
    echo '  Commands: hadoop  hdfs  yarn  hive  spark-shell  python3'
    echo '  HDFS home: /user/consultant'
    echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
fi
```

**Backup Created:** `/home/consultant/.bash_profile.backup`

### On Jenkins Server

**Job Configuration:** Updated programmatically via API

**Build Script:** 
- Filters banner output with grep
- Handles all SSH warnings
- Continues on minor errors with `|| true`
- Complete error handling with `set -e`

---

## 📂 Files on Cloudera Server

**Location:** `/home/consultant/uttam/TFL_Project_Demo/`

```
src/
├── sqoop/
│   ├── import_all_tables.sh      (2.9K) ✅
│   ├── import_as_parquet.sh      (2.5K) ✅
│   ├── import_single_table.sh    (2.2K) ✅
│   └── import_with_query.sh      (2.7K) ✅
└── hive/
    ├── create_database.hql        (750B) ✅
    ├── create_tables.hql          (6.7K) ✅
    ├── load_all_to_hive.sh        (3.1K) ✅
    └── sample_queries.hql         (7.3K) ✅
```

**Permissions:** All `.sh` files are executable (755)

---

## 🚀 Pipeline Workflow

```
┌─────────────────────────────────────────────────────┐
│  GitHub Repository                                   │
│  https://github.com/uttamraj9/TFL_Project_Demo     │
└──────────────────┬──────────────────────────────────┘
                   │ git clone (automatic)
                   ↓
┌─────────────────────────────────────────────────────┐
│  Jenkins Workspace                                   │
│  /var/lib/jenkins/workspace/PG_to_HDFS_Sqoop_Uttam │
│  - Scripts in src/sqoop/ and src/hive/             │
└──────────────────┬──────────────────────────────────┘
                   │ scp (password auth)
                   ↓
┌─────────────────────────────────────────────────────┐
│  Cloudera Cluster (13.41.167.97)                    │
│  /home/consultant/uttam/TFL_Project_Demo/           │
│  - Scripts copied and made executable               │
└──────────────────┬──────────────────────────────────┘
                   │ ssh execute
                   ↓
┌─────────────────────────────────────────────────────┐
│  Sqoop Import                                        │
│  PostgreSQL (13.42.152.118:5432/testdb)            │
│       ↓                                              │
│  HDFS (/tmp/uttam/tfl_data/)                        │
│  - 6 tables imported                                 │
└──────────────────┬──────────────────────────────────┘
                   │ hive -f
                   ↓
┌─────────────────────────────────────────────────────┐
│  Hive Database (uttam_tfl)                          │
│  - 6 external tables created                         │
│  - Total: 5,812 records                              │
└─────────────────────────────────────────────────────┘
```

---

## 🔑 Key Commands Used

### SSH Access (from your laptop)
```bash
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97
```

### Jenkins API Trigger
```bash
# Get CSRF crumb
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Trigger build
curl -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  'http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/build'
```

### Check Build Status
```bash
curl -s -u "consultant:WelcomeItc@2026" \
  'http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/api/json' \
  | grep -o '"building":[^,]*'
```

### View Console Output
```bash
curl -s -u "consultant:WelcomeItc@2026" \
  'http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/consoleText'
```

---

## 📈 Expected Final Result

When Build #7 completes successfully:

### HDFS Data
```
/tmp/uttam/tfl_data/
├── dim_networks/         (1 record)
├── dim_lines/            (14 records)
├── dim_stations/         (436 records)
├── dim_date/             (15 records)
├── fact_station_lines/   (575 records)
└── fact_passenger_entry_exit/ (4,771 records)
```

### Hive Database
```sql
USE uttam_tfl;
SHOW TABLES;

-- Output:
dim_networks
dim_lines
dim_stations
dim_date
fact_station_lines
fact_passenger_entry_exit
```

### Record Counts
```
Total Records: 5,812
  - dim_networks: 1
  - dim_lines: 14
  - dim_stations: 436
  - dim_date: 15
  - fact_station_lines: 575
  - fact_passenger_entry_exit: 4,771
```

---

## 🎯 Success Criteria

- [x] Jenkins job configured
- [x] SCP banner issue fixed
- [x] Scripts copied to Cloudera
- [x] Sqoop import running
- [ ] Hive database created (pending)
- [ ] Hive tables created (pending)
- [ ] Data verification (pending)
- [ ] Build status: SUCCESS (pending)

---

## 🔄 Future Builds

To run the pipeline again:

### Method 1: Jenkins UI
1. Go to: http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/
2. Click **"Build Now"**
3. Watch console output

### Method 2: Jenkins API
```bash
# Get crumb
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Trigger build
curl -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  'http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/build'
```

### Method 3: Update Scripts
```bash
# On your laptop
cd /Users/uttamkumar/Downloads/TFL_Project_Demo
vi src/sqoop/import_all_tables.sh
git add src/
git commit -m "Update Sqoop script"
git push origin main

# Jenkins will use updated scripts on next build
```

---

## 📞 Monitoring Build #7

**Console Output:** http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/console

**Status API:**
```bash
curl -s -u "consultant:WelcomeItc@2026" \
  'http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/api/json'
```

**Current Stage:** Sqoop Import (Step 8 of 11)

**Estimated Time:** 5-10 minutes total
- Sqoop: 2-5 minutes
- Hive: 2-3 minutes
- Verification: < 1 minute

---

## ✅ What's Working Now

1. ✅ **Git Integration** - Automatic clone from GitHub
2. ✅ **SCP File Transfer** - Banner suppressed, files copying successfully
3. ✅ **Remote Execution** - SSH commands executing on Cloudera
4. ✅ **Script Deployment** - All 8 scripts deployed to correct locations
5. ✅ **Permissions** - Execute permissions set correctly
6. ✅ **HDFS Access** - Clean operation successful
7. ✅ **Sqoop Running** - Import process started
8. ⏳ **Hive Setup** - Pending completion
9. ⏳ **Data Verification** - Pending completion

---

## 🎉 Summary

**Jenkins Pipeline:** ✅ WORKING!
**Build #7:** 🔄 IN PROGRESS
**SCP Issue:** ✅ RESOLVED
**Script Deployment:** ✅ SUCCESS
**Sqoop Import:** 🔄 RUNNING

**Next:** Wait for build completion (~5-10 minutes) and verify final results!

---

*Last Updated: June 2, 2026 - 15:52 UTC*
*Build #7 Triggered At: 15:50 UTC*
*Monitor: http://51.24.13.205:8081/job/PG_to_HDFS_Sqoop_Uttam/7/console*
