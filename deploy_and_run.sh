#!/bin/bash
# Deploy TfL Real-time Pipeline to Remote Server and Run

set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="ec2-user"
SSH_KEY="$HOME/Desktop/Training/test_key.pem"
PROJECT_NAME="TFL_Project_Demo"
REMOTE_DIR="/home/ec2-user/$PROJECT_NAME"
REPO_URL="https://github.com/uttamraj9/TFL_Project_Demo.git"

echo "========================================="
echo "TfL Real-time Pipeline - Deploy & Run"
echo "========================================="
echo ""

echo "1. Deploying Project to Remote Server..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    set -e
    cd /home/ec2-user

    # Remove old project if exists
    if [ -d "TFL_Project_Demo" ]; then
        echo "Removing old project..."
        rm -rf TFL_Project_Demo
    fi

    # Clone fresh copy
    echo "Cloning from GitHub..."
    git clone https://github.com/uttamraj9/TFL_Project_Demo.git

    echo "✅ Project deployed to /home/ec2-user/TFL_Project_Demo"
ENDSSH
echo ""

echo "2. Verifying Kafka & HBase Services..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
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

    if [ "$KAFKA_STATE" != "STARTED" ]; then
        echo "⚠️  Starting Kafka..."
        curl -X POST -u 'admin:Admin@2026' \
            'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka/commands/start'
        echo "Waiting for Kafka to start..."
        sleep 30
    fi

    if [ "$HBASE_STATE" != "STARTED" ]; then
        echo "⚠️  Starting HBase..."
        curl -X POST -u 'admin:Admin@2026' \
            'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase/commands/start'
        echo "Waiting for HBase to start..."
        sleep 30
    fi

    echo "✅ Services ready"
ENDSSH
echo ""

echo "3. Creating HBase Table..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "disable 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "drop 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "create 'tfl_arrivals', 'cf'" | hbase shell
    echo "✅ HBase table 'tfl_arrivals' created"
ENDSSH
echo ""

echo "4. Installing Python Dependencies..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    # Install kafka-python if not present
    python3 -c "import kafka" 2>/dev/null || {
        echo "Installing kafka-python..."
        pip3 install --user kafka-python requests
    }
    echo "✅ Dependencies installed"
ENDSSH
echo ""

echo "5. Starting Producer (TfL API → Kafka)..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/ec2-user/TFL_Project_Demo/src/realtime

    # Kill any existing producer
    pkill -f send_data_to_kafka 2>/dev/null || true

    # Start standalone producer in background
    nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
    PRODUCER_PID=$!
    echo "✅ Producer started (PID: $PRODUCER_PID)"
    echo "   Log: src/realtime/producer.log"

    # Wait a bit for first messages
    sleep 15

    # Check if messages are being published
    echo ""
    echo "Producer output (last 10 lines):"
    tail -10 producer.log
ENDSSH
echo ""

echo "6. Starting Consumer (Kafka → HBase)..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/ec2-user/TFL_Project_Demo/src/realtime

    # Kill any existing consumer
    pkill -f read_from_kafka_hbase.py 2>/dev/null || true

    # Start consumer in background
    nohup spark-submit \
        --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
        --conf spark.pyspark.python=/usr/bin/python3 \
        read_from_kafka_hbase.py > consumer.log 2>&1 &
    CONSUMER_PID=$!
    echo "✅ Consumer started (PID: $CONSUMER_PID)"
    echo "   Log: src/realtime/consumer.log"

    # Wait for Spark to initialize
    sleep 30
ENDSSH
echo ""

echo "7. Monitoring Pipeline (30 seconds)..."
sleep 30
echo ""

echo "8. Verifying Data in HBase..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "Scanning HBase table (first 5 records):"
    echo "scan 'tfl_arrivals', {LIMIT => 5}" | hbase shell 2>/dev/null | grep -A 20 "ROW"

    echo ""
    echo "Counting total records..."
    RECORD_COUNT=$(echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)" | awk '{print $1}')
    echo "✅ Total records in HBase: $RECORD_COUNT"
ENDSSH
echo ""

echo "========================================="
echo "✅ Pipeline Running Successfully!"
echo "========================================="
echo ""
echo "Processes running on remote server:"
echo "  - Producer: TfL API → Kafka (every 10 sec)"
echo "  - Consumer: Kafka → HBase (real-time streaming)"
echo ""
echo "To check status:"
echo "  ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST"
echo "  cd /home/ec2-user/TFL_Project_Demo/src/realtime"
echo "  tail -f producer.log"
echo "  tail -f consumer.log"
echo ""
echo "To stop:"
echo "  ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST"
echo "  pkill -f send_data_to_kafka.py"
echo "  pkill -f read_from_kafka_hbase.py"
echo ""
echo "To query HBase:"
echo "  ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST"
echo "  hbase shell"
echo "  scan 'tfl_arrivals', {LIMIT => 10}"
echo ""
