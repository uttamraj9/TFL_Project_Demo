#!/bin/bash
# Simple test script

echo "=== TfL Pipeline Test ==="

# Create HBase table
echo "create 'tfl_arrivals', 'cf'" | hbase shell 2>/dev/null || true

# Start producer
pkill -f producer.py
python3 producer.py > producer.log 2>&1 &
PROD_PID=$!
echo "Producer started: $PROD_PID"
sleep 15

# Start consumer
pkill -f consumer.py
python3 consumer.py > consumer.log 2>&1 &
CONS_PID=$!
echo "Consumer started: $CONS_PID"
sleep 30

# Show results
echo ""
echo "=== Producer Log ==="
tail -20 producer.log

echo ""
echo "=== Consumer Log ==="
tail -20 consumer.log

echo ""
echo "=== HBase Data ==="
echo "scan 'tfl_arrivals', {LIMIT => 5}" | hbase shell 2>/dev/null
echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null

echo ""
echo "=== Running Processes ==="
ps aux | grep -E "producer.py|consumer.py" | grep -v grep
