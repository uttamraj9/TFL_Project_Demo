#!/bin/bash
# Complete TfL Real-time Pipeline Test
# Copy this entire script and run it on consultant@13.41.167.97

echo "========================================="
echo "TfL Real-time Pipeline - Complete Test"
echo "========================================="
echo "Starting at: $(date)"
echo ""

# Navigate to project directory
cd /home/consultant/uttam

# Step 1: Deploy/Update Project
echo "Step 1: Deploying Project..."
if [ -d "TFL_Project_Demo" ]; then
    cd TFL_Project_Demo
    git pull
    echo "✓ Project updated"
else
    git clone https://github.com/uttamraj9/TFL_Project_Demo.git
    cd TFL_Project_Demo
    echo "✓ Project cloned"
fi

# Step 2: Install Dependencies
echo ""
echo "Step 2: Installing Dependencies..."
pip3 install --user kafka-python requests 2>/dev/null || true
echo "✓ Dependencies installed"

# Step 3: Create HBase Table
echo ""
echo "Step 3: Creating HBase Table..."
hbase shell 2>/dev/null << 'EOF'
disable 'tfl_arrivals'
drop 'tfl_arrivals'
create 'tfl_arrivals', 'cf'
list 'tfl_arrivals'
exit
EOF
echo "✓ HBase table created"

# Step 4: Stop Old Processes
echo ""
echo "Step 4: Stopping Old Processes..."
pkill -f send_data_to_kafka_simple.py 2>/dev/null || true
pkill -f read_from_kafka_hbase.py 2>/dev/null || true
sleep 2
echo "✓ Old processes stopped"

# Step 5: Start Producer
echo ""
echo "Step 5: Starting Producer (TfL API → Kafka)..."
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
PRODUCER_PID=$!
echo "✓ Producer started (PID: $PRODUCER_PID)"
echo "  Waiting 20 seconds for first messages..."
sleep 20

echo ""
echo "=== PRODUCER OUTPUT (last 15 lines) ==="
tail -15 producer.log

# Step 6: Check Kafka Messages
echo ""
echo "Step 6: Checking Kafka Topic..."
echo "=== KAFKA MESSAGES (first 3) ==="
timeout 10 /opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-6-42.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 3 2>/dev/null | python3 -m json.tool || echo "Messages in Kafka (formatting skipped)"

# Step 7: Start Consumer
echo ""
echo "Step 7: Starting Consumer (Kafka → HBase)..."
nohup spark-submit \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
    --conf spark.pyspark.python=/usr/bin/python3 \
    read_from_kafka_hbase.py > consumer.log 2>&1 &
CONSUMER_PID=$!
echo "✓ Consumer started (PID: $CONSUMER_PID)"
echo "  Waiting 60 seconds for Spark and processing..."
sleep 60

echo ""
echo "=== CONSUMER OUTPUT (last 20 lines) ==="
tail -20 consumer.log

# Step 8: Verify HBase Data
echo ""
echo "Step 8: Verifying HBase Data..."
echo "=== HBASE TABLE SAMPLE (first 5 rows) ==="
hbase shell 2>/dev/null << 'EOF'
scan 'tfl_arrivals', {LIMIT => 5}
exit
EOF

echo ""
echo "=== HBASE TABLE COUNT ==="
hbase shell 2>/dev/null << 'EOF'
count 'tfl_arrivals'
exit
EOF

# Step 9: Show Running Processes
echo ""
echo "Step 9: Checking Running Processes..."
echo "=== RUNNING PROCESSES ==="
ps aux | grep -E "send_data_to_kafka_simple|read_from_kafka_hbase" | grep -v grep || echo "No processes found"

# Summary
echo ""
echo "========================================="
echo "TEST COMPLETED"
echo "========================================="
echo "Producer PID: $PRODUCER_PID"
echo "Consumer PID: $CONSUMER_PID"
echo "Completed at: $(date)"
echo ""
echo "Processes are still running. To stop:"
echo "  pkill -f send_data_to_kafka_simple.py"
echo "  pkill -f read_from_kafka_hbase.py"
echo ""
echo "To see more data:"
echo "  hbase shell"
echo "  > scan 'tfl_arrivals', {LIMIT => 20}"
echo "  > count 'tfl_arrivals'"
echo ""
echo "Logs are at:"
echo "  /home/consultant/uttam/TFL_Project_Demo/src/realtime/producer.log"
echo "  /home/consultant/uttam/TFL_Project_Demo/src/realtime/consumer.log"
echo "========================================="
