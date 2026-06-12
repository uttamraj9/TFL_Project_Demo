#!/usr/bin/env python3
"""
TfL Real-time Data Consumer - HBase Version
Reads TfL arrivals from Kafka and writes to HBase
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, concat_ws, lit, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType

def foreach_batch_function(df, epoch_id):
    """Write each batch to HBase"""
    # Add rowkey (station + vehicle + timestamp)
    df_with_rowkey = df.withColumn(
        "rowkey",
        concat_ws("_", col("stationName"), col("vehicleId"), col("timestamp"))
    )

    # Write to HBase using Spark-HBase connector
    df_with_rowkey.write \
        .format("org.apache.hadoop.hbase.spark") \
        .option("hbase.table", "tfl_arrivals") \
        .option("hbase.columns.mapping",
                "rowkey STRING :key, "
                "stationName STRING cf:station, "
                "lineName STRING cf:line, "
                "towards STRING cf:towards, "
                "expectedArrival STRING cf:arrival, "
                "vehicleId STRING cf:vehicle, "
                "platformName STRING cf:platform, "
                "direction STRING cf:direction, "
                "destinationName STRING cf:destination, "
                "timeToStation STRING cf:time_to_station") \
        .option("hbase.spark.use.hbasecontext", "false") \
        .mode("append") \
        .save()

    print(f"✓ Batch {epoch_id}: Written {df.count()} records to HBase")

def main():
    # Create Spark Session with HBase support
    spark = SparkSession.builder \
        .appName("TfL_Kafka_HBase_Consumer") \
        .config("spark.hbase.host", "ip-172-31-3-85.eu-west-2.compute.internal") \
        .getOrCreate()

    # Kafka Configuration
    kafka_brokers = "ip-172-31-8-235.eu-west-2.compute.internal:9092,ip-172-31-14-3.eu-west-2.compute.internal:9092"
    kafka_topic = "tfl_arrivals"

    # HBase Configuration
    hbase_table = "tfl_arrivals"
    checkpoint_location = "/tmp/uttam/kafka/tfl_hbase/checkpoint"

    print(f"Starting TfL Kafka → HBase Consumer...")
    print(f"Kafka Topic: {kafka_topic}")
    print(f"HBase Table: {hbase_table}")
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

    # Write to HBase using foreachBatch
    query = parsed_df.writeStream \
        .foreachBatch(foreach_batch_function) \
        .option("checkpointLocation", checkpoint_location) \
        .outputMode("append") \
        .start()

    print("✓ Streaming started - writing to HBase")
    print("Press Ctrl+C to stop...")

    # Wait for termination
    query.awaitTermination()

if __name__ == "__main__":
    main()
