#!/bin/bash
# Run pipeline and verify data in Kafka and HBase

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="Cl0ud3ra@2026#Secur3!"

echo "========================================="
echo "Running Pipeline & Showing Results"
echo "========================================="
echo ""

echo "Step 1: Setup and start producer..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/consultant/uttam

    # Clone/update project
    if [ -d "TFL_Project_Demo" ]; then
        cd TFL_Project_Demo && git pull
    else
        git clone https://github.com/uttamraj9/TFL_Project_Demo.git
        cd TFL_Project_Demo
    fi

    # Install dependencies
    pip3 install --user kafka-python requests 2>/dev/null || true

    # Create HBase table
    echo "disable 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "drop 'tfl_arrivals'" | hbase shell 2>/dev/null || true
    echo "create 'tfl_arrivals', 'cf'" | hbase shell 2>/dev/null

    # Kill old processes
    pkill -f send_data_to_kafka 2>/dev/null || true
    pkill -f read_from_kafka 2>/dev/null || true

    cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

    # Start producer
    nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
    echo "Producer started, waiting 20 seconds for data..."
    sleep 20

    echo ""
    echo "=== PRODUCER LOG (last 20 lines) ==="
    tail -20 producer.log
ENDSSH

echo ""
echo ""
echo "Step 2: Check what's in KAFKA TOPIC..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "=== KAFKA TOPIC: tfl_arrivals ==="
    echo ""

    # Read messages from Kafka (limit to 5)
    /opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
        --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
        --topic tfl_arrivals \
        --from-beginning \
        --max-messages 5 2>/dev/null | python3 -m json.tool
ENDSSH

echo ""
echo ""
echo "Step 3: Start consumer (Kafka → HBase)..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    cd /home/consultant/uttam/TFL_Project_Demo/src/realtime

    # Start consumer
    nohup spark-submit \
        --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
        --conf spark.pyspark.python=/usr/bin/python3 \
        read_from_kafka_hbase.py > consumer.log 2>&1 &

    echo "Consumer started, waiting 40 seconds for Spark to initialize and process..."
    sleep 40

    echo ""
    echo "=== CONSUMER LOG (last 30 lines) ==="
    tail -30 consumer.log
ENDSSH

echo ""
echo ""
echo "Step 4: Check what's in HBASE..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    echo "=== HBASE TABLE: tfl_arrivals ==="
    echo ""

    echo "--- Sample Records (first 10) ---"
    echo "scan 'tfl_arrivals', {LIMIT => 10}" | hbase shell 2>/dev/null | \
        grep -A 15 "ROW" | head -100

    echo ""
    echo "--- Record Count ---"
    echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)"
ENDSSH

echo ""
echo ""
echo "========================================="
echo "Summary of Results"
echo "========================================="

sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" <<'ENDSSH'
    # Count Kafka messages
    KAFKA_COUNT=$(/opt/cloudera/parcels/CDH/bin/kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list ip-172-31-8-235.eu-west-2.compute.internal:9092 \
        --topic tfl_arrivals 2>/dev/null | awk -F ":" '{sum += $3} END {print sum}')

    # Count HBase rows
    HBASE_COUNT=$(echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)" | awk '{print $1}')

    echo "┌─────────────────────────────────────┐"
    echo "│         DATA VERIFICATION           │"
    echo "├─────────────────────────────────────┤"
    echo "│ Kafka Messages:  $KAFKA_COUNT"
    echo "│ HBase Rows:      $HBASE_COUNT"
    echo "└─────────────────────────────────────┘"
ENDSSH

echo ""
echo "To stop pipeline:"
echo "  ssh consultant@$REMOTE_HOST"
echo "  pkill -f send_data_to_kafka_simple.py"
echo "  pkill -f read_from_kafka_hbase.py"
