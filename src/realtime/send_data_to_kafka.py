#!/usr/bin/env python3
"""
TfL Real-time Data Producer
Fetches TfL Victoria Line arrivals and sends to Kafka
Converted from Scala to PySpark
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_json, struct
import requests
import time
import sys

def main():
    # Create Spark Session
    spark = SparkSession.builder \
        .appName("TfL_Kafka_Producer") \
        .getOrCreate()

    # TfL API Configuration
    api_url = "https://api.tfl.gov.uk/Line/victoria/Arrivals"
    api_params = {
        "app_id": "92293faa428041caad3dd647d39753a0",
        "app_key": "ba72936a3db54b4ba5792dc8f7acc043"
    }

    # Kafka Configuration
    kafka_brokers = "ip-172-31-6-42.eu-west-2.compute.internal:9092,ip-172-31-3-85.eu-west-2.compute.internal:9092,ip-172-31-12-74.eu-west-2.compute.internal:9092,ip-172-31-3-251.eu-west-2.compute.internal:9092"
    kafka_topic = "tfl_arrivals"

    print(f"Starting TfL Kafka Producer...")
    print(f"API: {api_url}")
    print(f"Kafka Topic: {kafka_topic}")
    print(f"Kafka Brokers: {kafka_brokers}")

    iteration = 0
    while True:
        try:
            iteration += 1
            print(f"\n[Iteration {iteration}] Fetching TfL data...")

            # Fetch data from TfL API
            response = requests.get(api_url, params=api_params, timeout=10)
            response.raise_for_status()
            json_text = response.text

            # Create DataFrame from JSON
            df = spark.read.json(spark.sparkContext.parallelize([json_text]))

            # Select required columns
            message_df = df.select(
                col("id"),
                col("stationName"),
                col("lineName"),
                col("towards"),
                col("expectedArrival"),
                col("vehicleId"),
                col("platformName"),
                col("direction"),
                col("destinationName"),
                col("timestamp"),
                col("timeToStation"),
                col("currentLocation"),
                col("timeToLive")
            )

            record_count = message_df.count()
            print(f"Fetched {record_count} arrival records")

            # Prepare for Kafka (key-value pairs)
            kafka_df = message_df.selectExpr(
                "CAST(id AS STRING) AS key",
                "to_json(struct(*)) AS value"
            )

            # Write to Kafka
            kafka_df.write \
                .format("kafka") \
                .option("kafka.bootstrap.servers", kafka_brokers) \
                .option("topic", kafka_topic) \
                .save()

            print(f"✓ Sent {record_count} messages to Kafka topic: {kafka_topic}")

            # Wait 10 seconds before next API call
            print("Waiting 10 seconds...")
            time.sleep(10)

        except requests.exceptions.RequestException as e:
            print(f"✗ API Error: {e}")
            time.sleep(10)
        except Exception as e:
            print(f"✗ Error: {e}")
            time.sleep(10)

if __name__ == "__main__":
    main()
