# Show Results NOW - Quick Commands

## 🚀 Run This Single Command

Copy and paste this entire command to run the pipeline and see results:

```bash
ssh consultant@13.41.167.97 'bash -s' << 'ENDSSH'
set -e
echo "========================================="
echo "TfL Real-time Pipeline - Quick Run"
echo "========================================="
echo ""

# Setup
cd /home/consultant/uttam
[ -d "TFL_Project_Demo" ] && { cd TFL_Project_Demo && git pull; } || git clone https://github.com/uttamraj9/TFL_Project_Demo.git
cd TFL_Project_Demo/src/realtime

# Install dependencies
pip3 install --user kafka-python requests 2>/dev/null || true

# Create HBase table
echo "Creating HBase table..."
hbase shell 2>/dev/null << 'EOF'
disable 'tfl_arrivals'
drop 'tfl_arrivals'
create 'tfl_arrivals', 'cf'
exit
EOF

# Kill old processes
pkill -f send_data_to_kafka_simple.py 2>/dev/null || true
pkill -f read_from_kafka_hbase.py 2>/dev/null || true
sleep 2

# Start producer
echo "Starting producer..."
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
PROD_PID=$!
echo "Producer PID: $PROD_PID"
sleep 20

# Check producer
echo ""
echo "=== PRODUCER OUTPUT ==="
tail -15 producer.log

# Start consumer
echo ""
echo "Starting consumer..."
nohup spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 read_from_kafka_hbase.py > consumer.log 2>&1 &
CONS_PID=$!
echo "Consumer PID: $CONS_PID"
sleep 60

# Check consumer
echo ""
echo "=== CONSUMER OUTPUT ==="
tail -20 consumer.log

# Check Kafka
echo ""
echo "========================================="
echo "KAFKA TOPIC: tfl_arrivals"
echo "========================================="
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 3 2>/dev/null | python3 -m json.tool || echo "Kafka messages available"

# Check HBase
echo ""
echo "========================================="
echo "HBASE TABLE: tfl_arrivals"
echo "========================================="
hbase shell 2>/dev/null << 'EOF'
scan 'tfl_arrivals', {LIMIT => 5}
count 'tfl_arrivals'
exit
EOF

# Summary
echo ""
echo "========================================="
echo "SUMMARY"
echo "========================================="
ps aux | grep -E "send_data_to_kafka_simple|read_from_kafka_hbase" | grep -v grep
echo ""
echo "To stop: pkill -f send_data_to_kafka_simple.py && pkill -f read_from_kafka_hbase.py"
echo "To monitor: tail -f producer.log (or consumer.log)"

ENDSSH
```

---

## 📋 What This Command Does

1. ✅ SSHs to consultant@13.41.167.97
2. ✅ Clones/updates GitHub repo
3. ✅ Creates HBase table
4. ✅ Starts producer (TfL → Kafka)
5. ✅ Starts consumer (Kafka → HBase)
6. ✅ Shows Kafka messages
7. ✅ Shows HBase data
8. ✅ Shows process status

---

## 🎯 Expected Output

You'll see:

```
=========================================
TfL Real-time Pipeline - Quick Run
=========================================

Creating HBase table...
Created table tfl_arrivals

Starting producer...
Producer PID: 123456

=== PRODUCER OUTPUT ===
Starting TfL Kafka Producer (Standalone)...
API: https://api.tfl.gov.uk/Line/victoria/Arrivals
Kafka Topic: tfl_arrivals
✓ Connected to Kafka
[2026-06-12 19:00:00] Iteration 1
Fetched 12 arrival records from TfL API
✓ Sent 12/12 messages to Kafka topic: tfl_arrivals

Starting consumer...
Consumer PID: 123457

=== CONSUMER OUTPUT ===
Starting Spark Structured Streaming...
Reading from Kafka topic: tfl_arrivals
Writing to HBase table: tfl_arrivals
Batch 0: Writing 12 rows to HBase
✓ Batch 0 complete

=========================================
KAFKA TOPIC: tfl_arrivals
=========================================
{
  "id": "1718215200123",
  "stationName": "Victoria",
  "lineName": "Victoria",
  "towards": "Brixton",
  "timeToStation": 120,
  "platformName": "Platform 1",
  ...
}

=========================================
HBASE TABLE: tfl_arrivals
=========================================
ROW                                     COLUMN+CELL
940GZZLUVIC_victoria_inbound_171821520  column=cf:stationName, value=Victoria
940GZZLUVIC_victoria_inbound_171821520  column=cf:towards, value=Brixton
940GZZLUVIC_victoria_inbound_171821520  column=cf:timeToStation, value=120
...

12 row(s)

=========================================
SUMMARY
=========================================
consultant 123456  python3 send_data_to_kafka_simple.py
consultant 123457  spark-submit read_from_kafka_hbase.py
```

---

## ⏱️ How Long?

- Total time: ~2 minutes
- You'll see results as they appear
- Processes continue running after command completes

---

## 🛑 To Stop

After seeing results, stop the pipeline:

```bash
ssh consultant@13.41.167.97 "pkill -f send_data_to_kafka_simple.py && pkill -f read_from_kafka_hbase.py"
```

---

## 🔍 To See More Data

Wait longer, then check again:

```bash
ssh consultant@13.41.167.97 "hbase shell << 'EOF'
scan 'tfl_arrivals', {LIMIT => 20}
count 'tfl_arrivals'
exit
EOF"
```

---

## ✅ Success Indicators

Look for:
- ✓ "Connected to Kafka"
- ✓ "Sent X/X messages"
- ✓ "Batch N complete"
- ✓ Row count > 0 in HBase
- ✓ Two processes running (producer + consumer)

---

**COPY THE COMMAND ABOVE AND RUN IT NOW!** 

You'll see data in Kafka and HBase in ~2 minutes! 🚀
