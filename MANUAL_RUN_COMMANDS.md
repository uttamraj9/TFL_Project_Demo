# Manual Commands to Run Pipeline and See Results

## Step 1: SSH to Server

```bash
ssh consultant@13.41.167.97
# Password: WelcomeItc@2026
```

---

## Step 2: Setup and Start Producer

```bash
# Navigate to project directory
cd /home/consultant/uttam

# Clone or update project
if [ -d "TFL_Project_Demo" ]; then
    cd TFL_Project_Demo && git pull
else
    git clone https://github.com/uttamraj9/TFL_Project_Demo.git
    cd TFL_Project_Demo
fi

# Install dependencies
pip3 install --user kafka-python requests

# Create HBase table
hbase shell <<EOF
disable 'tfl_arrivals'
drop 'tfl_arrivals'
create 'tfl_arrivals', 'cf'
exit
EOF

# Navigate to realtime directory
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

# Kill any old processes
pkill -f send_data_to_kafka
pkill -f read_from_kafka

# Start producer in background
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &

# Wait and check
sleep 20
tail -20 producer.log
```

---

## Step 3: Check KAFKA TOPIC (What's in Kafka)

```bash
# Read first 5 messages from Kafka topic
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 5 | python3 -m json.tool

# Press Ctrl+C after seeing messages
```

**Expected Output:**
```json
{
    "id": "1234567890",
    "stationName": "Victoria",
    "lineName": "Victoria",
    "lineId": "victoria",
    "towards": "Brixton",
    "direction": "inbound",
    "platformName": "Platform 1",
    "destinationName": "Brixton",
    "expectedArrival": "2026-06-12T17:30:00Z",
    "timeToStation": 120,
    "vehicleId": "123",
    "currentLocation": "At Victoria",
    "timestamp": "2026-06-12T17:28:00Z"
}
```

---

## Step 4: Start Consumer (Kafka → HBase)

```bash
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

# Start consumer
nohup spark-submit \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
    --conf spark.pyspark.python=/usr/bin/python3 \
    read_from_kafka_hbase.py > consumer.log 2>&1 &

# Wait for Spark to initialize and process
echo "Waiting 40 seconds for Spark..."
sleep 40

# Check consumer log
tail -30 consumer.log
```

**Expected in Consumer Log:**
```
Starting Spark Structured Streaming...
Reading from Kafka topic: tfl_arrivals
Writing to HBase table: tfl_arrivals
Batch 0: Writing 15 rows to HBase
Batch 1: Writing 12 rows to HBase
```

---

## Step 5: Check HBASE TABLE (What's in HBase)

```bash
hbase shell
```

### In HBase Shell:

**Get sample records:**
```
scan 'tfl_arrivals', {LIMIT => 10}
```

**Expected Output:**
```
ROW                                          COLUMN+CELL
940GZZLUVIC_victoria_inbound_1718211930     column=cf:destinationName, timestamp=1718211930000, value=Brixton
940GZZLUVIC_victoria_inbound_1718211930     column=cf:direction, timestamp=1718211930000, value=inbound
940GZZLUVIC_victoria_inbound_1718211930     column=cf:expectedArrival, timestamp=1718211930000, value=2026-06-12T17:32:10Z
940GZZLUVIC_victoria_inbound_1718211930     column=cf:lineId, timestamp=1718211930000, value=victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:lineName, timestamp=1718211930000, value=Victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:platformName, timestamp=1718211930000, value=Platform 1
940GZZLUVIC_victoria_inbound_1718211930     column=cf:stationName, timestamp=1718211930000, value=Victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:timeToStation, timestamp=1718211930000, value=120
940GZZLUVIC_victoria_inbound_1718211930     column=cf:towards, timestamp=1718211930000, value=Brixton
940GZZLUVIC_victoria_inbound_1718211930     column=cf:vehicleId, timestamp=1718211930000, value=123
```

**Count total rows:**
```
count 'tfl_arrivals'
```

**Expected:**
```
300 row(s)
```

**Exit HBase shell:**
```
exit
```

---

## Step 6: Summary Commands

### Check Kafka Message Count
```bash
/opt/cloudera/parcels/CDH/bin/kafka-run-class kafka.tools.GetOffsetShell \
    --broker-list ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals | awk -F ":" '{sum += $3} END {print "Kafka messages:", sum}'
```

### Check HBase Row Count
```bash
echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)"
```

### Check Processes Running
```bash
ps aux | grep -E "send_data_to_kafka_simple|read_from_kafka_hbase" | grep -v grep
```

---

## Step 7: Stop Pipeline (When Done)

```bash
# Kill producer
pkill -f send_data_to_kafka_simple.py

# Kill consumer
pkill -f read_from_kafka_hbase.py

# Verify stopped
ps aux | grep -E "send_data_to_kafka|read_from_kafka" | grep -v grep
```

---

## 📊 What You'll See

### In KAFKA Topic:
- **Raw JSON messages** from TfL API
- Each message contains full arrival details
- ~9-15 arrivals per API call
- 1 API call every 10 seconds

### In HBase Table:
- **Structured rows** with row key: `{station}_{line}_{direction}_{timestamp}`
- Each column in `cf` column family
- Easy to query by station, line, or time
- Optimized for real-time lookups

### Data Flow:
```
TfL API Response (JSON)
    ↓
Kafka Topic (JSON messages)
    ↓
Spark Streaming (transformation)
    ↓
HBase Table (structured rows with columns)
```

---

## 🎯 Copy-Paste Commands (All in One)

```bash
# SSH
ssh consultant@13.41.167.97

# Setup
cd /home/consultant/uttam
[ -d "TFL_Project_Demo" ] && cd TFL_Project_Demo && git pull || git clone https://github.com/uttamraj9/TFL_Project_Demo.git
cd TFL_Project_Demo/src/realtime
pip3 install --user kafka-python requests

# HBase table
echo -e "disable 'tfl_arrivals'\ndrop 'tfl_arrivals'\ncreate 'tfl_arrivals', 'cf'\nexit" | hbase shell

# Start producer
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
sleep 20 && tail producer.log

# Check Kafka
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 --topic tfl_arrivals --from-beginning --max-messages 3 | python3 -m json.tool

# Start consumer
nohup spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 read_from_kafka_hbase.py > consumer.log 2>&1 &
sleep 40 && tail consumer.log

# Check HBase
echo -e "scan 'tfl_arrivals', {LIMIT => 5}\ncount 'tfl_arrivals'\nexit" | hbase shell
```

---

**Now you'll see the actual data in both Kafka and HBase!** 🚀
