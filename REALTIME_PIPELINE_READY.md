# TfL Real-time Streaming Pipeline - Ready to Run

**Status:** ✅ Kafka & HBase Started, Pipeline Ready

---

## Services Status (via CM API)

| Service | Status | URL |
|---------|--------|-----|
| **Kafka** | ✅ STARTED | Brokers: ip-172-31-8-235:9092, ip-172-31-14-3:9092 |
| **HBase** | ✅ STARTED | Master: ip-172-31-3-85 |

**Verified:**
- Kafka brokers running
- HBase table `tfl_arrivals` created with column family `cf`
- Kafka topic `tfl_arrivals` exists

---

## Pipeline Architecture

```
TfL API (Victoria Line)
    ↓ (every 10 sec)
Kafka Topic: tfl_arrivals
    ↓ (Spark Structured Streaming)
HBase Table: tfl_arrivals
    ↓
Query via hbase shell
```

---

## Files

### Jenkinsfile
**Location:** `src/realtime/Jenkinsfile`

**What it does:**
1. Checks Kafka & HBase status via Cloudera Manager API
2. Auto-starts services if stopped
3. Creates HBase table and Kafka topic
4. Runs producer (TfL API → Kafka)
5. Runs consumer (Kafka → HBase)
6. Verifies data with hbase shell
7. Stops jobs after duration

### Producer
**File:** `src/realtime/send_data_to_kafka.py`
- Fetches TfL Victoria Line arrivals API
- Sends to Kafka every 10 seconds
- JSON format with key=id

### Consumer
**File:** `src/realtime/read_from_kafka_hbase.py`
- Reads from Kafka (Structured Streaming)
- Writes to HBase table `tfl_arrivals`
- RowKey: stationName_vehicleId_timestamp
- Column family: `cf`

---

## How to Run in Jenkins

### Step 1: Create Jenkins Job

1. Go to: http://51.24.13.205:8081/
2. Login: consultant / WelcomeItc@2026
3. New Item → Pipeline
4. Name: `TfL_Realtime_HBase`

### Step 2: Configure

**Pipeline Section:**
- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository: `https://github.com/uttamraj9/TFL_Project_Demo.git`
- Branch: `*/main`
- **Script Path:** `src/realtime/Jenkinsfile`

### Step 3: Build with Parameters

**Parameters:**
```
MODE = both
DURATION_MINUTES = 5
```

**What happens:**
1. Checks/starts Kafka & HBase (via CM API)
2. Creates HBase table (if not exists)
3. Creates Kafka topic (if not exists)
4. Starts producer → runs 5 minutes
5. Starts consumer → runs 5 minutes
6. Shows HBase record count
7. Shows sample records
8. Stops jobs

---

## Expected Output

### Stage: Check Services via CM API
```
Kafka: STARTED
HBase: STARTED
✓ Services checked
```

### Stage: Create HBase Table
```
Created table tfl_arrivals
✓ HBase table ready: tfl_arrivals
```

### Stage: Create Kafka Topic
```
✓ Topic exists
```

### Stage: Run Producer
```
[Iteration 1] Fetching TfL data...
Fetched 42 arrival records
✓ Sent 42 messages to Kafka topic: tfl_arrivals
Waiting 10 seconds...
```

### Stage: Run HBase Consumer
```
Streaming started - writing to HBase
✓ Batch 0: Written 42 records to HBase
```

### Stage: Verify HBase Data
```
count 'tfl_arrivals'
210 row(s)

Sample records:
ROW: Brixton_123_2026-06-12T15:45:00Z
 cf:station => Brixton
 cf:line => Victoria
 cf:arrival => 2026-06-12T15:46:30Z
 cf:time_to_station => 90
```

---

## Manual Testing (SSH)

### Connect to Cluster
```bash
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97
```

### Check HBase Data
```bash
hbase shell

# Count records
count 'tfl_arrivals'

# Scan first 10 records
scan 'tfl_arrivals', {LIMIT => 10}

# Get specific record
get 'tfl_arrivals', 'rowkey_here'

# Exit
exit
```

### Check Kafka Messages
```bash
kafka-console-consumer \
  --bootstrap-server ip-172-31-8-235:9092 \
  --topic tfl_arrivals \
  --from-beginning \
  --max-messages 5
```

---

## Cloudera Manager API Commands

### Check Service Status
```bash
curl -u "admin:Admin@2026" \
  "http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka"
```

### Start Kafka
```bash
curl -X POST -u "admin:Admin@2026" \
  "http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka/commands/start"
```

### Start HBase
```bash
curl -X POST -u "admin:Admin@2026" \
  "http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase/commands/start"
```

---

## HBase Table Schema

**Table:** `tfl_arrivals`

**Column Family:** `cf`

**Columns:**
| Column | Description |
|--------|-------------|
| cf:station | Station name (e.g., "Brixton") |
| cf:line | Line name (always "Victoria") |
| cf:towards | Direction/destination |
| cf:arrival | Expected arrival time |
| cf:vehicle | Vehicle ID |
| cf:platform | Platform name |
| cf:direction | Direction (inbound/outbound) |
| cf:destination | Final destination |
| cf:time_to_station | Time to station in seconds |

**RowKey Format:** `{stationName}_{vehicleId}_{timestamp}`

Example: `Brixton_123_2026-06-12T15:45:00Z`

---

## Troubleshooting

### Kafka Not Started
Pipeline will auto-start via CM API, or manually:
```bash
curl -X POST -u "admin:Admin@2026" \
  "http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka/commands/start"
```

### HBase Not Started
Pipeline will auto-start, or check:
```bash
curl -u "admin:Admin@2026" \
  "http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase"
```

### No Data in HBase
- Check producer is running: `ps aux | grep send_data_to_kafka`
- Check Kafka has messages: `kafka-console-consumer ...`
- Check consumer logs: `/tmp/consumer_hbase.log`

### TfL API Rate Limit
Producer fetches every 10 seconds. If API limits hit, increase sleep time in `send_data_to_kafka.py`

---

## Architecture Details

### Producer Flow
```
TfL API
  ↓ HTTP GET every 10 sec
PySpark DataFrame
  ↓ JSON parsing
Kafka Topic (tfl_arrivals)
  - Key: arrival ID
  - Value: JSON record
```

### Consumer Flow
```
Kafka Topic
  ↓ readStream
Spark Structured Streaming
  ↓ foreachBatch
HBase Connector
  ↓ write
HBase Table (tfl_arrivals)
```

---

## Next Steps

1. ✅ Services started
2. ✅ HBase table created
3. ✅ Kafka topic created
4. **→ Run Jenkins pipeline**
5. Verify data in HBase
6. Query real-time arrivals

---

**Pipeline is ready to run!** 🚀

Create the Jenkins job and build with `MODE=both`
