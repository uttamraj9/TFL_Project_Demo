#!/usr/bin/env python3
"""
Simple PySpark Word Count Example
Demonstrates PySpark functionality on Cloudera cluster
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
import sys

def main():
    print("="*80)
    print("Simple PySpark Word Count Demo")
    print("="*80)

    # Create Spark session
    print("\n1. Creating Spark session...")
    spark = SparkSession.builder \
        .appName("TfL_Simple_WordCount") \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")
    print(f"✓ Spark version: {spark.version}")

    # Create sample data
    print("\n2. Creating sample TfL station data...")
    data = [
        "Kings Cross St Pancras station is very busy",
        "Oxford Circus station serves multiple lines",
        "Stratford station is a major transport hub",
        "Waterloo station has high passenger volume",
        "Bank station connects to multiple lines",
        "Liverpool Street station serves commuters",
        "Victoria station is central location",
        "London Bridge station has high traffic",
        "Paddington station serves west London",
        "Canary Wharf station is busy business district"
    ]

    df = spark.createDataFrame([(line,) for line in data], ["text"])
    print(f"✓ Created {df.count()} sample records")

    # Word count analysis
    print("\n3. Performing word count analysis...")
    words_df = df.select(explode(split(col("text"), " ")).alias("word"))
    word_counts = words_df.groupBy("word") \
        .count() \
        .orderBy(col("count").desc())

    print("\nTop 20 Most Frequent Words:")
    word_counts.show(20, truncate=False)

    # Station analysis
    print("\n4. Analyzing station mentions...")
    station_words = words_df.filter(col("word").contains("station"))
    print(f"✓ Found {station_words.count()} mentions of 'station'")

    # Save results
    output_path = "/tmp/uttam/spark_wordcount_output"
    print(f"\n5. Saving results to HDFS: {output_path}")
    try:
        word_counts.coalesce(1).write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(output_path)
        print("✓ Results saved successfully")
    except Exception as e:
        print(f"Warning: Could not save to HDFS: {e}")
        print("(This is OK for demo purposes)")

    # Summary
    print("\n" + "="*80)
    print("Analysis Summary:")
    print("="*80)
    print(f"Total words processed: {words_df.count()}")
    print(f"Unique words: {word_counts.count()}")
    print(f"Most common word: {word_counts.first()['word']} ({word_counts.first()['count']} times)")
    print("="*80)
    print("✓✓✓ PySpark Job Completed Successfully!")
    print("="*80)

    spark.stop()
    print("\n✓ Spark session stopped")

if __name__ == "__main__":
    main()
