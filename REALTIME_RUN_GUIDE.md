# TfL Real-time Pipeline - Execution Guide

## 🎯 Two Ways to Run

### Option 1: Jenkins Pipeline (Recommended) ✅

**Best for:** Production use, scheduled runs, full automation

**Steps:**
1. Open Jenkins: http://51.24.13.205:8081/
2. Create Pipeline job: `TfL-Realtime-Pipeline`
3. Configure:
   - SCM: Git
   - Repository: https://github.com/uttamraj9/TFL_Project_Demo.git
   - Script Path: `src/realtime/Jenkinsfile`
4. Build with Parameters:
   - MODE: `both`
   - DURATION_MINUTES: `5`

**Why Jenkins?**
- ✅ Runs on **consultant@13.41.167.97** (edge node with Kafka access)
- ✅ Auto-starts Kafka & HBase via Cloudera Manager API
- ✅ Creates HBase table automatically
- ✅ Full logging and monitoring
- ✅ Runs both producer and consumer
- ✅ Verifies data in HBase

---

### Option 2: Manual SSH Execution

**Best for:** Testing, debugging, one-off runs

**Requirements:**
- Must SSH as **consultant** user (has Kafka access)
- ec2-user does NOT have Kafka permissions

**Steps:**

#### 1. SSH to Edge Node
```bash
# Use consultant user (NOT ec2-user)
ssh consultant@13.41.167.97
# Password: WelcomeItc@2026
```

#### 2. Deploy Project
```bash
cd /home/consultant/uttam
rm -rf TFL_Project_Demo  # Remove old version
git clone https://github.com/uttamraj9/TFL_Project_Demo.git
cd TFL_Project_Demo/src/realtime
```

#### 3. Verify Services
```bash
# Check Kafka
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka' | \
  python3 -c "import json,sys; print('Kafka:', json.load(sys.stdin)['serviceState'])"

# Check HBase
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase' | \
  python3 -c "import json,sys; print('HBase:', json.load(sys.stdin)['serviceState'])"
```

#### 4. Create HBase Table
```bash
hbase shell
> disable 'tfl_arrivals'   # If exists
> drop 'tfl_arrivals'      # If exists
> create 'tfl_arrivals', 'cf'
> exit
```

#### 5. Install Dependencies
```bash
# Install kafka-python if not present
pip3 install --user kafka-python requests
```

#### 6. Start Producer
```bash
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

# Start in background
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &

# Check it's running
tail -f producer.log
# Press Ctrl+C to stop tailing
```

#### 7. Start Consumer
```bash
# In new terminal or same terminal
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

# Start Spark streaming consumer
nohup spark-submit \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
  --conf spark.pyspark.python=/usr/bin/python3 \
  read_from_kafka_hbase.py > consumer.log 2>&1 &

# Check it's running
tail -f consumer.log
# Press Ctrl+C to stop tailing
```

#### 8. Verify Data
```bash
# Wait 30 seconds for data to flow

# Check HBase
hbase shell
> scan 'tfl_arrivals', {LIMIT => 10}
> count 'tfl_arrivals'
> exit
```

#### 9. Stop Pipeline
```bash
# Kill producer
pkill -f send_data_to_kafka_simple.py

# Kill consumer
pkill -f read_from_kafka_hbase.py

# Verify stopped
ps aux | grep tfl
```

---

## 🔍 Current Status

### ✅ Working
- Kafka: STARTED (verified via CM API)
- HBase: STARTED (verified via CM API)
- TfL API: Responding (9 arrivals)
- HBase table: Created (`tfl_arrivals`)
- Producer script: Deployed
- Consumer script: Deployed

### ⚠️ Issue Found
- **ec2-user** cannot connect to Kafka brokers
- **Solution:** Use **consultant** user (edge node with Kafka access)

### 🎯 Recommended Approach
**Use Jenkins Pipeline** - It runs as consultant user and handles everything automatically.

---

## 📊 Expected Results (5-minute run)

**Kafka:**
- ~30 messages published (1 every 10 seconds)

**HBase:**
- 300-500 rows (multiple arrivals per API call)
- Row format: `{station}_{line}_{direction}_{timestamp}`

**Console:**
```
[2026-06-12 17:30:00] Iteration 1
Fetched 9 arrival records from TfL API
✓ Sent 9/9 messages to Kafka topic: tfl_arrivals
Waiting 10 seconds...
```

---

## 🚨 Troubleshooting

### NoBrokersAvailable Error
**Cause:** Wrong user (ec2-user doesn't have Kafka access)
**Solution:** SSH as consultant user

### Permission Denied
**Cause:** Not using edge node
**Solution:** Use consultant@13.41.167.97

### Table Already Exists
**Solution:**
```bash
hbase shell
> disable 'tfl_arrivals'
> drop 'tfl_arrivals'
> create 'tfl_arrivals', 'cf'
```

### No Data in HBase
**Check:**
1. Producer running: `ps aux | grep send_data_to_kafka_simple`
2. Producer log: `tail producer.log`
3. Consumer running: `ps aux | grep read_from_kafka_hbase`
4. Consumer log: `tail consumer.log`

---

## 📝 Summary

| Method | User | Access | Automation | Recommended |
|--------|------|--------|------------|-------------|
| Jenkins | consultant | ✅ Kafka | Full | ✅ Yes |
| Manual SSH | consultant | ✅ Kafka | Manual | Testing only |
| SSH ec2-user | ec2-user | ❌ No Kafka | N/A | ❌ No |

**Bottom Line:** Use Jenkins for production, consultant SSH for debugging.

---

## 🔗 Quick Links

- Jenkins: http://51.24.13.205:8081/
- Cloudera Manager: http://13.41.167.97:7180/ (admin/Admin@2026)
- GitHub: https://github.com/uttamraj9/TFL_Project_Demo
- TfL API: https://api.tfl.gov.uk/

---

**Next Steps:** Set up the Jenkins job using [JENKINS_SETUP_GUIDE.md](./JENKINS_SETUP_GUIDE.md)
