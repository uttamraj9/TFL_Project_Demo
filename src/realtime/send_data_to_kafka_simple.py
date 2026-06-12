#!/usr/bin/env python3
"""
TfL Real-time Data Producer (Standalone)
Fetches TfL Victoria Line arrivals and sends to Kafka
Uses kafka-python library (no Spark required)
"""

import json
import time
import requests
from kafka import KafkaProducer
from datetime import datetime

def main():
    # Kafka Configuration
    kafka_brokers = ["ip-172-31-8-235.eu-west-2.compute.internal:9092",
                     "ip-172-31-14-3.eu-west-2.compute.internal:9092"]
    kafka_topic = "tfl_arrivals"

    # TfL API Configuration
    api_url = "https://api.tfl.gov.uk/Line/victoria/Arrivals"
    api_params = {
        "app_id": "92293faa428041caad3dd647d39753a0",
        "app_key": "ba72936a3db54b4ba5792dc8f7acc043"
    }

    print(f"Starting TfL Kafka Producer (Standalone)...")
    print(f"API: {api_url}")
    print(f"Kafka Topic: {kafka_topic}")
    print(f"Kafka Brokers: {kafka_brokers}")

    # Create Kafka Producer
    try:
        producer = KafkaProducer(
            bootstrap_servers=kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None
        )
        print("✓ Connected to Kafka")
    except Exception as e:
        print(f"✗ Failed to connect to Kafka: {e}")
        return

    iteration = 0
    while True:
        try:
            iteration += 1
            print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Iteration {iteration}")

            # Fetch data from TfL API
            response = requests.get(api_url, params=api_params, timeout=10)
            response.raise_for_status()
            arrivals = response.json()

            print(f"Fetched {len(arrivals)} arrival records from TfL API")

            # Send each arrival to Kafka
            sent_count = 0
            for arrival in arrivals:
                try:
                    # Use arrival ID as key
                    key = arrival.get('id', '')

                    # Send to Kafka
                    future = producer.send(kafka_topic, key=key, value=arrival)
                    # Wait for send to complete (optional, for reliability)
                    future.get(timeout=10)
                    sent_count += 1
                except Exception as e:
                    print(f"✗ Error sending message: {e}")

            producer.flush()
            print(f"✓ Sent {sent_count}/{len(arrivals)} messages to Kafka topic: {kafka_topic}")

            # Wait 10 seconds before next API call
            print("Waiting 10 seconds...")
            time.sleep(10)

        except requests.exceptions.RequestException as e:
            print(f"✗ TfL API Error: {e}")
            time.sleep(10)
        except KeyboardInterrupt:
            print("\n\nShutting down producer...")
            break
        except Exception as e:
            print(f"✗ Unexpected Error: {e}")
            time.sleep(10)

    producer.close()
    print("Producer stopped")

if __name__ == "__main__":
    main()
