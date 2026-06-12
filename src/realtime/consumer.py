#!/usr/bin/env python3
"""Kafka to HBase Consumer"""

import sys
import json
import happybase
from kafka import KafkaConsumer
from datetime import datetime

# Force unbuffered output
sys.stdout = sys.stdout.reconfigure(line_buffering=True) if hasattr(sys.stdout, 'reconfigure') else sys.stdout

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

def main():
    kafka_brokers = [
        "ip-172-31-6-42.eu-west-2.compute.internal:9092",
        "ip-172-31-3-251.eu-west-2.compute.internal:9092",
        "ip-172-31-3-85.eu-west-2.compute.internal:9092",
        "ip-172-31-12-74.eu-west-2.compute.internal:9092"
    ]
    kafka_topic = "tfl_arrivals"
    hbase_host = "ip-172-31-12-74.eu-west-2.compute.internal"
    hbase_table = "tfl_arrivals"

    log("Starting Kafka → HBase Consumer...")
    log(f"Kafka topic: {kafka_topic}")
    log(f"HBase table: {hbase_table}")

    # Connect to Kafka
    log("Connecting to Kafka...")
    try:
        consumer = KafkaConsumer(
            kafka_topic,
            bootstrap_servers=kafka_brokers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            auto_offset_reset='earliest',
            group_id='tfl-hbase-consumer',
            enable_auto_commit=True
        )
        log("✓ Kafka connected")
    except Exception as e:
        log(f"✗ Kafka connection failed: {e}")
        sys.exit(1)

    # Connect to HBase
    log("Connecting to HBase...")
    try:
        connection = happybase.Connection(hbase_host)
        table = connection.table(hbase_table)
        log("✓ HBase connected")
    except Exception as e:
        log(f"✗ HBase connection failed: {e}")
        sys.exit(1)

    # Process messages
    log("Consuming messages...")
    count = 0
    batch = []
    batch_size = 10

    try:
        for message in consumer:
            try:
                data = message.value

                # Create row key
                station = data.get('stationName', 'unknown')
                line = data.get('lineName', 'unknown')
                direction = data.get('direction', 'unknown')
                timestamp = data.get('timestamp', str(int(time.time())))
                row_key = f"{station}_{line}_{direction}_{timestamp}".encode('utf-8')

                # Prepare HBase row
                row_data = {
                    b'cf:stationName': str(data.get('stationName', '')).encode('utf-8'),
                    b'cf:lineName': str(data.get('lineName', '')).encode('utf-8'),
                    b'cf:towards': str(data.get('towards', '')).encode('utf-8'),
                    b'cf:expectedArrival': str(data.get('expectedArrival', '')).encode('utf-8'),
                    b'cf:platformName': str(data.get('platformName', '')).encode('utf-8'),
                    b'cf:direction': str(data.get('direction', '')).encode('utf-8'),
                    b'cf:timeToStation': str(data.get('timeToStation', '')).encode('utf-8'),
                    b'cf:vehicleId': str(data.get('vehicleId', '')).encode('utf-8')
                }

                batch.append((row_key, row_data))
                count += 1

                # Write batch to HBase
                if len(batch) >= batch_size:
                    table.put_batch(batch)
                    batch = []
                    log(f"✓ Wrote {count} rows to HBase")

            except Exception as e:
                log(f"✗ Processing error: {e}")
                continue

    except KeyboardInterrupt:
        log("\nShutting down...")
    finally:
        if batch:
            table.put_batch(batch)
            log(f"✓ Wrote final {len(batch)} rows")
        connection.close()
        consumer.close()
        log(f"Consumer stopped. Total rows: {count}")

if __name__ == "__main__":
    import time
    main()
