#!/bin/bash
# Run TfL Real-time Pipeline manually as consultant user (edge node)

set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "========================================="
echo "TfL Real-time Pipeline - Manual Run"
echo "Running as: $REMOTE_USER@$REMOTE_HOST"
echo "========================================="
echo ""

echo "Note: This uses consultant user (edge node with Kafka access)"
echo "      ec2-user cannot access Kafka brokers"
echo ""

echo "1. Deploying Project..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    set -e
    cd /home/consultant/uttam

    # Remove old project if exists
    if [ -d "TFL_Project_Demo" ]; then
        echo "Removing old project..."
        rm -rf TFL_Project_Demo
    fi

    # Clone fresh copy
    echo "Cloning from GitHub..."
    git clone https://github.com/uttamraj9/TFL_Project_Demo.git

    echo "✅ Project deployed to /home/consultant/uttam/TFL_Project_Demo"
ENDSSH
echo ""

echo "2. Verifying Kafka & HBase Services..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    # Check Kafka
    KAFKA_STATE=$(curl -s -u 'admin:Admin@2026' \
        'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka' | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['serviceState'])")
    echo "Kafka: $KAFKA_STATE"

    # Check HBase
    HBASE_STATE=$(curl -s -u 'admin:Admin@2026' \
        'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase' | \
        python3 -c "import json,sys; print(json.load(sys.stdin)['serviceState'])")
    echo "HBase: $HBASE_STATE"

    echo "✅ Services ready"
ENDSSH
echo ""

echo "3. Creating HBase Table..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "disable 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "drop 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "create 'tfl_arrivals', 'cf'" | hbase shell 2>/dev/null | grep -i "created\|table"
    echo "✅ HBase table 'tfl_arrivals' ready"
ENDSSH
echo ""

echo "4. Installing Python Dependencies..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    # Install kafka-python if not present
    python3 -c "import kafka" 2>/dev/null || {
        echo "Installing kafka-python..."
        pip3 install --user kafka-python requests
    }
    echo "✅ Dependencies installed"
ENDSSH
echo ""

echo "5. Starting Producer (TfL API → Kafka)..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

    # Kill any existing producer
    pkill -f send_data_to_kafka_simple.py 2>/dev/null || true
    sleep 2

    # Start standalone producer in background
    nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
    PRODUCER_PID=$!
    echo "✅ Producer started (PID: $PRODUCER_PID)"
    echo "   Log: /home/consultant/uttam/TFL_Project_Demo/src/realtime/producer.log"

    # Wait for first messages
    sleep 15

    # Check if messages are being published
    echo ""
    echo "Producer output (last 15 lines):"
    tail -15 producer.log
ENDSSH
echo ""

echo "6. Starting Consumer (Kafka → HBase)..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

    # Kill any existing consumer
    pkill -f read_from_kafka_hbase.py 2>/dev/null || true
    sleep 2

    # Start Spark streaming consumer in background
    nohup spark-submit \
        --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
        --conf spark.pyspark.python=/usr/bin/python3 \
        read_from_kafka_hbase.py > consumer.log 2>&1 &
    CONSUMER_PID=$!
    echo "✅ Consumer started (PID: $CONSUMER_PID)"
    echo "   Log: /home/consultant/uttam/TFL_Project_Demo/src/realtime/consumer.log"

    # Wait for Spark to initialize
    echo "   Waiting 30 seconds for Spark to initialize..."
    sleep 30
ENDSSH
echo ""

echo "7. Monitoring Pipeline (20 seconds)..."
sleep 20
echo ""

echo "8. Verifying Data in HBase..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "Scanning HBase table (first 5 records):"
    echo "scan 'tfl_arrivals', {LIMIT => 5}" | hbase shell 2>/dev/null | grep -E "ROW|column=|row\(s\)" | head -30

    echo ""
    echo "Counting total records..."
    COUNT=$(echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)" | head -1 | awk '{print $1}')
    echo "✅ Total records in HBase: $COUNT"
ENDSSH
echo ""

echo "9. Checking Process Status..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "Running processes:"
    ps aux | grep -E "send_data_to_kafka_simple|read_from_kafka_hbase" | grep -v grep || echo "No processes found"
ENDSSH
echo ""

echo "========================================="
echo "✅ Pipeline Running!"
echo "========================================="
echo ""
echo "To monitor:"
echo "  ssh consultant@$REMOTE_HOST"
echo "  cd /home/consultant/uttam/TFL_Project_Demo/src/realtime"
echo "  tail -f producer.log"
echo "  tail -f consumer.log"
echo ""
echo "To verify data:"
echo "  hbase shell"
echo "  scan 'tfl_arrivals', {LIMIT => 10}"
echo "  count 'tfl_arrivals'"
echo ""
echo "To stop:"
echo "  pkill -f send_data_to_kafka_simple.py"
echo "  pkill -f read_from_kafka_hbase.py"
echo ""
