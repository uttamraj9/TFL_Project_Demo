#!/usr/bin/env python3
"""TfL to Kafka Producer"""

import sys
import json
import time
import requests
from kafka import KafkaProducer
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
    api_url = "https://api.tfl.gov.uk/Line/victoria/Arrivals"

    log("Starting TfL Producer...")
    log(f"Kafka: {len(kafka_brokers)} brokers")
    log(f"Topic: {kafka_topic}")

    # Connect to Kafka with timeout
    log("Connecting to Kafka...")
    try:
        producer = KafkaProducer(
            bootstrap_servers=kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: str(k).encode('utf-8'),
            request_timeout_ms=30000,
            api_version_auto_timeout_ms=30000
        )
        log("✓ Kafka connected")
    except Exception as e:
        log(f"✗ Kafka connection failed: {e}")
        sys.exit(1)

    iteration = 0
    while True:
        try:
            iteration += 1
            log(f"\n=== Iteration {iteration} ===")

            # Fetch from TfL API
            log("Fetching from TfL API...")
            response = requests.get(api_url, timeout=10)
            response.raise_for_status()
            arrivals = response.json()
            log(f"✓ Fetched {len(arrivals)} arrivals")

            # Send to Kafka
            sent = 0
            for arrival in arrivals:
                try:
                    producer.send(
                        kafka_topic,
                        key=arrival.get('id', 'unknown'),
                        value=arrival
                    )
                    sent += 1
                except Exception as e:
                    log(f"✗ Send error: {e}")

            producer.flush()
            log(f"✓ Sent {sent}/{len(arrivals)} messages to Kafka")

            log("Waiting 10 seconds...")
            time.sleep(10)

        except requests.exceptions.RequestException as e:
            log(f"✗ API error: {e}")
            time.sleep(10)
        except KeyboardInterrupt:
            log("\nShutting down...")
            break
        except Exception as e:
            log(f"✗ Error: {e}")
            time.sleep(10)

    producer.close()
    log("Producer stopped")

if __name__ == "__main__":
    main()
