# Jenkins Setup & Verification Guide
## TfL Real-time Pipeline

---

## 📋 Quick Setup (5 Minutes)

### Step 1: Access Jenkins
**URL:** http://51.24.13.205:8081/

### Step 2: Create New Pipeline Job

1. Click **"New Item"** (top left sidebar)
2. Enter name: `TfL-Realtime-Pipeline`
3. Select: **Pipeline**
4. Click: **OK**

### Step 3: Configure Job

**General Section:**
- ✅ Description: `Real-time TfL arrivals streaming: Kafka → HBase`

**Pipeline Section:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
- Branch Specifier: `*/main`
- Script Path: `src/realtime/Jenkinsfile`

Click **Save**

### Step 4: Build with Parameters

Click **"Build with Parameters"** on the left sidebar:

**Recommended Settings:**
- `MODE`: **both** (runs producer + consumer together)
- `DURATION_MINUTES`: **5** (runs for 5 minutes)

Click **Build**

---

## 🔍 Monitoring the Build

### Console Output

Watch the **Console Output** to see stages:

```
Stage 1: Check Services via CM API
  ✅ Kafka: STARTED
  ✅ HBase: STARTED

Stage 2: Ensure Services Running
  ✅ Starting Kafka if needed...
  ✅ Starting HBase if needed...

Stage 3: Create HBase Table
  ✅ Table 'tfl_arrivals' created

Stage 4: Run Producer (if MODE=producer or both)
  ✅ Fetching from TfL API every 10 seconds
  ✅ Publishing to Kafka topic: tfl_arrivals

Stage 5: Run HBase Consumer (if MODE=consumer_hbase or both)
  ✅ Spark Structured Streaming started
  ✅ Reading from Kafka
  ✅ Writing to HBase

Stage 6: Verify Data
  ✅ Scanning HBase table...
  ✅ Found N records
```

---

## ✅ Manual Verification (After Job Completes)

### Option 1: SSH Verification

```bash
# Connect to cluster
ssh consultant@13.41.167.97
# Password: WelcomeItc@2026

# Check HBase data
hbase shell

# Inside HBase shell:
scan 'tfl_arrivals', {LIMIT => 10}
count 'tfl_arrivals'
exit
```

### Option 2: Check Logs on Remote Server

```bash
ssh consultant@13.41.167.97
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

# Check producer logs
cat producer.log

# Check consumer logs  
cat consumer.log
```

---

## 🧪 Test Individual Components

### Test Producer Only
**Parameters:**
- MODE: `producer`
- DURATION_MINUTES: `2`

**Expected:** Data published to Kafka topic `tfl_arrivals`

### Test Consumer Only
**Parameters:**
- MODE: `consumer_hbase`
- DURATION_MINUTES: `3`

**Expected:** Data consumed from Kafka and written to HBase

### Test Full Pipeline
**Parameters:**
- MODE: `both`
- DURATION_MINUTES: `5`

**Expected:** End-to-end streaming from TfL API → Kafka → HBase

---

## 📊 What Each Mode Does

### MODE=producer
- Fetches live TfL arrivals every 10 seconds
- Publishes JSON to Kafka topic: `tfl_arrivals`
- Kafka brokers: `ip-172-31-8-235:9092`, `ip-172-31-14-3:9092`

### MODE=consumer_hbase
- Uses Spark Structured Streaming
- Reads from Kafka topic: `tfl_arrivals`
- Writes to HBase table: `tfl_arrivals`
- Row key format: `{station}_{line}_{direction}_{timestamp}`

### MODE=both
- Runs both producer and consumer in parallel
- Full end-to-end pipeline
- Recommended for first run

---

## 🔧 Sample HBase Data

After running, you should see data like:

```
ROW                                    COLUMN+CELL
940GZZLUVIC_victoria_inbound_1234567  column=cf:destinationName, value=Brixton
940GZZLUVIC_victoria_inbound_1234567  column=cf:expectedArrival, value=2026-06-12T16:45:30Z
940GZZLUVIC_victoria_inbound_1234567  column=cf:lineId, value=victoria
940GZZLUVIC_victoria_inbound_1234567  column=cf:lineName, value=Victoria
940GZZLUVIC_victoria_inbound_1234567  column=cf:platformName, value=Platform 1
940GZZLUVIC_victoria_inbound_1234567  column=cf:stationName, value=Victoria
940GZZLUVIC_victoria_inbound_1234567  column=cf:timeToStation, value=120
940GZZLUVIC_victoria_inbound_1234567  column=cf:towards, value=Brixton
940GZZLUVIC_victoria_inbound_1234567  column=cf:vehicleId, value=123
```

---

## 🚨 Troubleshooting

### Build Fails at "Check Services"
**Issue:** Kafka or HBase not running
**Solution:** Pipeline auto-starts them via CM API (Stage 2)

### "Connection refused" to Kafka
**Issue:** Kafka brokers unreachable
**Solution:** Check Cloudera Manager at http://13.41.167.97:7180/

### "Table already exists" error
**Issue:** HBase table from previous run
**Solution:** Pipeline drops and recreates automatically

### No data in HBase
**Issue:** Producer not running or TfL API down
**Solution:** Check Console Output for producer errors

### Build Never Finishes
**Issue:** Duration too long
**Solution:** Stop build manually, reduce DURATION_MINUTES

---

## 📈 Expected Results

After a **5-minute run with MODE=both**, you should see:

- **Kafka:** ~30 messages (1 every 10 seconds × 5 minutes)
- **HBase:** ~300-500 rows (multiple arrivals per API call)
- **Console:** Success messages for all stages

---

## 🎯 Success Criteria

✅ Jenkins job completes without errors
✅ Console shows "Kafka: STARTED" and "HBase: STARTED"
✅ Producer logs show "Published ... messages"
✅ Consumer logs show "Writing to HBase..."
✅ `hbase shell scan` returns data
✅ HBase count > 0

---

## 🔗 Quick Links

| Resource | URL |
|----------|-----|
| Jenkins | http://51.24.13.205:8081/ |
| Cloudera Manager | http://13.41.167.97:7180/ (admin/Admin@2026) |
| TfL API Docs | https://api.tfl.gov.uk/ |
| GitHub Repo | https://github.com/uttamraj9/TFL_Project_Demo |

---

## 🆘 Need Help?

1. Check **Console Output** in Jenkins for detailed logs
2. SSH to cluster and check HBase: `hbase shell`
3. Review Jenkinsfile: `src/realtime/Jenkinsfile`
4. Check producer script: `src/realtime/send_data_to_kafka.py`
5. Check consumer script: `src/realtime/read_from_kafka_hbase.py`

---

**Ready to run!** Follow the steps above to start streaming real-time TfL data. 🚀
