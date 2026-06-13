#!/usr/bin/env python3
"""
TfL Real-time Data Consumer
Reads TfL arrivals from Kafka and writes to HDFS
Converted from Scala to PySpark with Structured Streaming
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType

def main():
    # Create Spark Session
    spark = SparkSession.builder \
        .appName("TfL_Kafka_Consumer") \
        .getOrCreate()

    # Kafka Configuration
    kafka_brokers = "ip-172-31-6-42.eu-west-2.compute.internal:9092,ip-172-31-3-85.eu-west-2.compute.internal:9092,ip-172-31-12-74.eu-west-2.compute.internal:9092,ip-172-31-3-251.eu-west-2.compute.internal:9092"
    kafka_topic = "tfl_arrivals"

    # HDFS Output Configuration
    checkpoint_location = "/tmp/uttam/kafka/tfl_arrivals/checkpoint"
    output_path = "/tmp/uttam/kafka/tfl_arrivals/data"

    print(f"Starting TfL Kafka Consumer...")
    print(f"Kafka Topic: {kafka_topic}")
    print(f"Kafka Brokers: {kafka_brokers}")
    print(f"Output Path: {output_path}")
    print(f"Checkpoint: {checkpoint_location}")

    # Define schema for TfL arrival data
    schema = StructType([
        StructField("id", StringType(), True),
        StructField("stationName", StringType(), True),
        StructField("lineName", StringType(), True),
        StructField("towards", StringType(), True),
        StructField("expectedArrival", StringType(), True),
        StructField("vehicleId", StringType(), True),
        StructField("platformName", StringType(), True),
        StructField("direction", StringType(), True),
        StructField("destinationName", StringType(), True),
        StructField("timestamp", StringType(), True),
        StructField("timeToStation", StringType(), True),
        StructField("currentLocation", StringType(), True),
        StructField("timeToLive", StringType(), True)
    ])

    # Read from Kafka as streaming DataFrame
    kafka_df = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", kafka_brokers) \
        .option("subscribe", kafka_topic) \
        .option("startingOffsets", "latest") \
        .load()

    # Parse JSON from Kafka value
    parsed_df = kafka_df.select(
        from_json(col("value").cast("string"), schema).alias("data")
    ).selectExpr("data.*")

    # Write to HDFS as CSV with streaming
    query = parsed_df.writeStream \
        .format("csv") \
        .option("checkpointLocation", checkpoint_location) \
        .option("path", output_path) \
        .option("header", "true") \
        .outputMode("append") \
        .start()

    print("✓ Streaming started - writing to HDFS")
    print("Press Ctrl+C to stop...")

    # Wait for termination
    query.awaitTermination()

if __name__ == "__main__":
    main()
