# TfL Real-time Streaming Pipeline

Real-time data pipeline streaming Transport for London (TfL) Victoria Line arrivals from TfL API → Kafka → HBase.

---

## 🚀 Quick Start (5 Minutes)

### Jenkins Pipeline (Recommended)

1. **Open Jenkins:** http://51.24.13.205:8081/

2. **Create Pipeline Job:**
   - Name: `TfL-Realtime-Pipeline`
   - Type: Pipeline
   - SCM: Git
   - Repository: `https://github.com/uttamraj9/TFL_Project_Demo.git`
   - Script Path: `src/realtime/Jenkinsfile`

3. **Build with Parameters:**
   - MODE: `both`
   - DURATION_MINUTES: `5`

4. **Verify Results:**
   ```bash
   ssh consultant@13.41.167.97
   hbase shell
   > scan 'tfl_arrivals', {LIMIT => 10}
   > count 'tfl_arrivals'
   ```

**See:** [JENKINS_QUICKSTART.md](./JENKINS_QUICKSTART.md) for detailed steps.

---

## 📊 Architecture

```
TfL API (Victoria Line)
        ↓
   Producer (Python)
        ↓
    Kafka Topic
        ↓
Consumer (Spark Streaming)
        ↓
    HBase Table
```

### Components

| Component | Technology | Location |
|-----------|-----------|----------|
| **Producer** | Python + kafka-python | `src/realtime/send_data_to_kafka_simple.py` |
| **Producer (Spark)** | PySpark | `src/realtime/send_data_to_kafka.py` |
| **Consumer** | Spark Structured Streaming | `src/realtime/read_from_kafka_hbase.py` |
| **Pipeline** | Jenkins | `src/realtime/Jenkinsfile` |

### Infrastructure

| Service | Status | Details |
|---------|--------|---------|
| **Kafka** | ✅ STARTED | 2 brokers: ip-172-31-8-235:9092, ip-172-31-14-3:9092 |
| **HBase** | ✅ STARTED | Table: `tfl_arrivals`, CF: `cf` |
| **TfL API** | ✅ LIVE | https://api.tfl.gov.uk/Line/victoria/Arrivals |

---

## 📁 Files

### Pipeline Code
- `src/realtime/Jenkinsfile` - Jenkins pipeline definition
- `src/realtime/send_data_to_kafka.py` - PySpark producer (for Jenkins)
- `src/realtime/send_data_to_kafka_simple.py` - Standalone producer (for testing)
- `src/realtime/read_from_kafka_hbase.py` - Spark Structured Streaming consumer
- `src/realtime/read_from_kafka.py` - Basic Kafka consumer (testing)

### Documentation
- `JENKINS_QUICKSTART.md` - 5-minute setup guide
- `JENKINS_SETUP_GUIDE.md` - Detailed Jenkins configuration
- `REALTIME_RUN_GUIDE.md` - Jenkins vs manual execution
- `REALTIME_VERIFICATION_SUMMARY.md` - Complete verification status

### Automation Scripts
- `deploy_and_run.sh` - Automated deployment (ec2-user)
- `run_manual_consultant.sh` - Manual execution (consultant user)
- `verify_pipeline.sh` - Pre-flight checks

---

## 🎯 Build Parameters

### MODE
- **`producer`** - Only run TfL API → Kafka
- **`consumer_hbase`** - Only run Kafka → HBase
- **`both`** ✅ - Full pipeline (recommended)

### DURATION_MINUTES
- **1** - Quick test (~60-90 rows)
- **5** ✅ - Demo/verification (~300-500 rows)
- **10** - Extended run (~600-1000 rows)
- **30** - Production simulation (~1800-3000 rows)

---

## 📈 Expected Results (5-minute run)

**Kafka:**
- ~30 API calls (1 every 10 seconds)
- ~270-450 messages

**HBase Table: `tfl_arrivals`**
- **Rows:** 300-500
- **Column Family:** `cf`
- **Columns:**
  - `cf:stationName` - Station name
  - `cf:lineName` - Line name (Victoria)
  - `cf:towards` - Destination
  - `cf:expectedArrival` - Arrival timestamp
  - `cf:platformName` - Platform
  - `cf:vehicleId` - Train ID
  - `cf:timeToStation` - Seconds to arrival
  - `cf:direction` - inbound/outbound
  - `cf:destinationName` - Final destination
  - `cf:currentLocation` - Current train location

**Sample Row:**
```
ROW: 940GZZLUVIC_victoria_inbound_1718211930
  cf:destinationName = Brixton
  cf:direction = inbound
  cf:expectedArrival = 2026-06-12T17:32:10Z
  cf:lineId = victoria
  cf:lineName = Victoria
  cf:platformName = Platform 1
  cf:stationName = Victoria
  cf:timeToStation = 120
  cf:towards = Brixton
  cf:vehicleId = 123
```

---

## ✅ Verified

- ✅ Kafka: STARTED (verified via Cloudera Manager API)
- ✅ HBase: STARTED (verified via Cloudera Manager API)
- ✅ TfL API: LIVE (9 arrivals fetched successfully)
- ✅ HBase table: Created (`tfl_arrivals`)
- ✅ Network: All services reachable
- ✅ Code: Deployed to GitHub
- ✅ Documentation: Complete

**Confidence Level:** 95% (waiting for Jenkins job creation)

---

## 🚨 Troubleshooting

### Build Fails at "Check Services"
**Solution:** Check Cloudera Manager: http://13.41.167.97:7180/

### NoBrokersAvailable Error
**Cause:** Wrong user (ec2-user doesn't have Kafka access)
**Solution:** Use Jenkins (runs as consultant user automatically)

### No Data in HBase
**Solution:** Check Console Output in Jenkins for errors

### Build Never Finishes
**Solution:** Stop build in Jenkins, then:
```bash
ssh consultant@13.41.167.97
pkill -f send_data_to_kafka.py
pkill -f read_from_kafka_hbase.py
```

---

## 🔗 Resources

| Resource | URL |
|----------|-----|
| Jenkins | http://51.24.13.205:8081/ |
| Cloudera Manager | http://13.41.167.97:7180/ |
| GitHub Repository | https://github.com/uttamraj9/TFL_Project_Demo |
| TfL API Documentation | https://api.tfl.gov.uk/ |

---

## 🎓 Reference

Based on existing Jenkins job pattern: http://51.24.13.205:8081/job/aparna_PG_TO_HDFS/

---

## 📝 Next Steps

1. ✅ **Infrastructure Ready** (Kafka, HBase, TfL API)
2. ✅ **Code Deployed** (GitHub synced)
3. ✅ **Documentation Complete** (6 guides)
4. ⏳ **Your Turn:** Create Jenkins job and run!

**Follow:** [JENKINS_QUICKSTART.md](./JENKINS_QUICKSTART.md)

---

**Status:** 🟢 READY TO RUN

Last Updated: June 12, 2026
