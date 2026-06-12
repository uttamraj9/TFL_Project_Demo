# Jenkins Quick Start - TfL Real-time Pipeline

## 🚀 5-Minute Setup

### Step 1: Open Jenkins
Navigate to: **http://51.24.13.205:8081/**

Login with your Jenkins credentials.

---

### Step 2: Create New Pipeline Job

1. Click **"New Item"** (left sidebar)
2. Enter name: **`TfL-Realtime-Pipeline`**
3. Select: **Pipeline**
4. Click: **OK**

---

### Step 3: Configure the Job

Scroll down to the **Pipeline** section:

**Pipeline Definition:**
- Select: **"Pipeline script from SCM"**

**SCM:**
- Select: **Git**

**Repository URL:**
```
https://github.com/uttamraj9/TFL_Project_Demo.git
```

**Branch Specifier:**
```
*/main
```

**Script Path:**
```
src/realtime/Jenkinsfile
```

**Save** the configuration.

---

### Step 4: Run the Job

1. Click **"Build with Parameters"** (left sidebar)

2. Set parameters:
   - **MODE:** Select **`both`** (runs producer + consumer together)
   - **DURATION_MINUTES:** Enter **`5`** (runs for 5 minutes)

3. Click **"Build"**

---

### Step 5: Monitor Execution

Click on the build number (e.g., **#1**) in the left sidebar, then click **"Console Output"**.

**You should see:**

```
Stage 1: Check Services via CM API
  ✅ Kafka: STARTED
  ✅ HBase: STARTED

Stage 2: Ensure Services Running
  ✅ Services verified

Stage 3: Create HBase Table
  ✅ Table 'tfl_arrivals' created

Stage 4: Run Producer (Mode: both)
  ✅ Producer started
  ✅ Fetching from TfL API every 10 seconds
  ✅ Publishing to Kafka topic: tfl_arrivals

Stage 5: Run HBase Consumer (Mode: both)
  ✅ Spark Structured Streaming started
  ✅ Reading from Kafka
  ✅ Writing to HBase

Stage 6: Verify Data
  ✅ Scanning HBase table...
  ✅ Found XXX records

SUCCESS
```

---

## ✅ Verification

After the job completes (5 minutes), verify data manually:

### Option A: SSH Verification

```bash
ssh consultant@13.41.167.97
# Password: WelcomeItc@2026

hbase shell
```

In HBase shell:
```
scan 'tfl_arrivals', {LIMIT => 10}
count 'tfl_arrivals'
exit
```

**Expected:** 300-500 rows (real-time TfL arrivals)

---

### Option B: Check Logs in Jenkins Console

The Jenkins console output will show:
- Producer: Number of messages sent
- Consumer: Number of rows written to HBase
- Verification: Sample records from HBase

---

## 🎯 What the Pipeline Does

| Stage | Action | Result |
|-------|--------|--------|
| **1. Check Services** | Query Cloudera Manager API | Kafka & HBase status |
| **2. Ensure Running** | Auto-start services if stopped | Services ready |
| **3. Create Table** | Drop & recreate HBase table | Fresh table `tfl_arrivals` |
| **4. Producer** | Fetch TfL API → Kafka every 10s | Real-time data in Kafka |
| **5. Consumer** | Spark Streaming: Kafka → HBase | Real-time data in HBase |
| **6. Verify** | Scan & count HBase table | Data validation |

---

## 📊 Expected Results (5-minute run)

**Kafka:**
- ~30 API calls (1 every 10 seconds)
- ~270-450 messages (9-15 arrivals per call)

**HBase Table: `tfl_arrivals`**
- 300-500 rows
- Column family: `cf`
- Columns:
  - `cf:stationName` - Victoria line stations
  - `cf:lineName` - Victoria
  - `cf:towards` - Destination
  - `cf:expectedArrival` - Arrival timestamp
  - `cf:platformName` - Platform number
  - `cf:vehicleId` - Train ID
  - `cf:timeToStation` - Seconds to arrival
  - And more...

---

## 🔧 Build Parameters Explained

### MODE Options:

| Mode | Description | Use Case |
|------|-------------|----------|
| **`producer`** | Only runs TfL API → Kafka | Test producer alone |
| **`consumer_hbase`** | Only runs Kafka → HBase | Test consumer alone (needs existing Kafka data) |
| **`both`** ✅ | Runs producer + consumer together | Full end-to-end pipeline (recommended) |

### DURATION_MINUTES:

| Value | Runtime | Messages | Use Case |
|-------|---------|----------|----------|
| **1** | 1 minute | ~60-90 rows | Quick test |
| **5** ✅ | 5 minutes | ~300-500 rows | Demo/verification |
| **10** | 10 minutes | ~600-1000 rows | Extended monitoring |
| **30** | 30 minutes | ~1800-3000 rows | Production simulation |

---

## 🚨 Troubleshooting

### Build Fails at "Check Services"
**Issue:** Kafka or HBase not reachable
**Solution:** Check Cloudera Manager: http://13.41.167.97:7180/

### "Connection refused" to Kafka
**Issue:** Services stopped
**Solution:** Jenkins auto-starts them (Stage 2). If still failing, start manually in CM.

### No Data in HBase
**Issue:** Producer or Consumer failed
**Solution:** Check Console Output for error messages. Common causes:
- TfL API down (check https://api.tfl.gov.uk/Line/victoria/Arrivals)
- Kafka not accepting messages
- Spark submit failed

### Build Never Finishes
**Issue:** Duration too long or stuck process
**Solution:** 
1. Click "Stop" button in Jenkins
2. SSH to server and kill processes:
```bash
ssh consultant@13.41.167.97
pkill -f send_data_to_kafka.py
pkill -f read_from_kafka_hbase.py
```

---

## 🎓 Reference Job

Based on existing Jenkins setup: **http://51.24.13.205:8081/job/aparna_PG_TO_HDFS/**

Your new job follows the same pattern:
- ✅ Pipeline from SCM (Git)
- ✅ Parameterized build
- ✅ Remote execution via SSH
- ✅ Cloudera Manager API integration

---

## 📁 Files Used

| File | Purpose |
|------|---------|
| `src/realtime/Jenkinsfile` | Pipeline definition (auto-loaded from Git) |
| `src/realtime/send_data_to_kafka.py` | Producer (PySpark-based) |
| `src/realtime/read_from_kafka_hbase.py` | Consumer (Spark Structured Streaming) |

---

## 🔗 Quick Links

| Resource | URL |
|----------|-----|
| Jenkins | http://51.24.13.205:8081/ |
| Cloudera Manager | http://13.41.167.97:7180/ (admin/Admin@2026) |
| GitHub Repo | https://github.com/uttamraj9/TFL_Project_Demo |
| TfL API | https://api.tfl.gov.uk/Line/victoria/Arrivals |

---

## ✨ Next Steps

1. **First Run:** Use MODE=`both`, DURATION=`5` to verify everything works
2. **Check Data:** SSH and run `hbase shell` to see real-time arrivals
3. **Scale Up:** Increase DURATION_MINUTES for longer monitoring
4. **Schedule:** Add build triggers for automated runs (hourly, daily)

---

**That's it! Your real-time TfL data pipeline is ready to run.** 🚀

Any issues? Check:
1. Jenkins Console Output (detailed logs)
2. Cloudera Manager (service status)
3. [REALTIME_RUN_GUIDE.md](./REALTIME_RUN_GUIDE.md) (troubleshooting)
4. [JENKINS_SETUP_GUIDE.md](./JENKINS_SETUP_GUIDE.md) (detailed setup)
