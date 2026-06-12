#!/bin/bash
# Simple test script

echo "=== TfL Pipeline Test ==="

# Create HBase table
echo "disable 'tfl_arrivals'; drop 'tfl_arrivals'; create 'tfl_arrivals', 'cf'" | hbase shell 2>/dev/null || true

# Start producer
pkill -f producer.py
python3 producer.py > producer.log 2>&1 &
PROD_PID=$!
echo "Producer started: $PROD_PID"
sleep 15

# Start Spark consumer
pkill -f read_from_kafka_hbase.py
spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
    read_from_kafka_hbase.py > consumer.log 2>&1 &
CONS_PID=$!
echo "Consumer started: $CONS_PID"
sleep 45

# Show results
echo ""
echo "=== Producer Log ==="
tail -20 producer.log

echo ""
echo "=== Consumer Log ==="
tail -30 consumer.log

echo ""
echo "=== HBase Data ==="
echo "scan 'tfl_arrivals', {LIMIT => 5}" | hbase shell 2>/dev/null
echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null

echo ""
echo "=== Running Processes ==="
ps aux | grep -E "producer.py|read_from_kafka_hbase.py" | grep -v grep
