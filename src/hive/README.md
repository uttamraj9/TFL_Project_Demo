# TfL Data Warehouse - Hive Setup

## 📁 Scripts Overview

This directory contains Hive scripts for creating database, tables, and loading data from HDFS.

### Files

| File | Description |
|------|-------------|
| `create_database.hql` | Creates uttam_tfl database |
| `create_tables.hql` | Creates all 6 tables (4 dim, 1 bridge, 1 fact) |
| `load_all_to_hive.sh` | Master script - runs everything in order |
| `sample_queries.hql` | 10 analytical queries for testing |
| `README.md` | This documentation |

---

## 🚀 Quick Start

### Prerequisites

1. **HDFS data loaded** - Run Sqoop imports first:
   ```bash
   cd ../sqoop
   ./import_all_tables.sh
   ```

2. **Verify HDFS data**:
   ```bash
   hdfs dfs -ls /tmp/uttam/tfl_data
   ```

### One-Command Setup

```bash
cd src/hive
chmod +x *.sh
./load_all_to_hive.sh
```

This will:
1. Create `uttam_tfl` database
2. Create all 6 tables
3. Load data from HDFS
4. Verify record counts

---

## 📊 Database Structure

### Database: `uttam_tfl`

**Tables:** 6 (Total: 5,812 records)

#### Dimension Tables
- `dim_networks` (1 record) - Network types
- `dim_lines` (14 records) - Tube/rail lines  
- `dim_stations` (436 records) - Station master data
- `dim_date` (15 records) - Time dimension (2007-2021)

#### Bridge Table
- `fact_station_lines` (575 records) - Station-line relationships

#### Fact Table
- `fact_passenger_entry_exit` (4,771 records) - Passenger statistics

---

## 📝 Manual Setup (Step-by-Step)

### Step 1: Create Database

```bash
hive -f create_database.hql
```

**Or via Hive CLI:**
```sql
CREATE DATABASE IF NOT EXISTS uttam_tfl;
USE uttam_tfl;
```

### Step 2: Create Tables

```bash
hive -f create_tables.hql
```

### Step 3: Verify

```sql
USE uttam_tfl;
SHOW TABLES;

-- Count records
SELECT COUNT(*) FROM dim_stations;
SELECT COUNT(*) FROM fact_passenger_entry_exit;
```

---

## 🔍 Sample Queries

Run all sample queries:
```bash
hive -f sample_queries.hql
```

### Top 10 Busiest Stations (2019)

```sql
USE uttam_tfl;

SELECT
    s.station_name,
    SUM(f.total_entry_exit) AS total_passengers
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year = 2019
GROUP BY s.station_name
ORDER BY total_passengers DESC
LIMIT 10;
```

### Stations by Line

```sql
SELECT
    l.line_name,
    COUNT(DISTINCT sl.station_id) AS station_count
FROM dim_lines l
JOIN fact_station_lines sl ON l.line_id = sl.line_id
GROUP BY l.line_name
ORDER BY station_count DESC;
```

### Year-over-Year Growth

```sql
SELECT
    d.year,
    SUM(f.total_entry_exit) AS total_passengers,
    ROUND(SUM(f.total_entry_exit) / 1000000, 2) AS passengers_millions
FROM fact_passenger_entry_exit f
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.is_annual = TRUE
GROUP BY d.year
ORDER BY d.year;
```

---

## ⚙️ Configuration

### HDFS Locations

Tables are created as **EXTERNAL** tables pointing to HDFS:

```
/tmp/uttam/tfl_data/
├── dim_networks/
├── dim_lines/
├── dim_stations/
├── dim_date/
├── fact_station_lines/
└── fact_passenger_entry_exit/
```

### Table Format

- **Storage:** TEXTFILE (CSV format)
- **Delimiter:** Comma (,)
- **Header:** First line skipped (`skip.header.line.count=1`)
- **Type:** EXTERNAL (data stays in HDFS)

---

## 🔧 Troubleshooting

### Issue: "Database does not exist"

**Solution:**
```bash
hive -e "CREATE DATABASE IF NOT EXISTS uttam_tfl;"
```

### Issue: "Table not found"

**Solution:**
```bash
# Check current database
hive -e "SELECT current_database();"

# Use correct database
hive -e "USE uttam_tfl; SHOW TABLES;"
```

### Issue: "No data in tables"

**Solution:** Verify HDFS data exists
```bash
hdfs dfs -ls /tmp/uttam/tfl_data/dim_stations
hdfs dfs -cat /tmp/uttam/tfl_data/dim_stations/part-m-00000 | head -5
```

### Issue: "Permission denied"

**Solution:** Check HDFS permissions
```bash
hdfs dfs -chmod -R 755 /tmp/uttam/tfl_data
```

---

## 📈 Performance Tips

### Use Parquet for Better Performance

After loading text data, convert to Parquet:

```sql
-- Create Parquet table
CREATE TABLE dim_stations_parquet
STORED AS PARQUET
AS SELECT * FROM dim_stations;

-- Create Parquet fact table
CREATE TABLE fact_passenger_entry_exit_parquet
STORED AS PARQUET
AS SELECT * FROM fact_passenger_entry_exit;
```

**Benefits:**
- 50-80% smaller size
- Faster queries (columnar)
- Better compression

### Enable Compression

```sql
SET hive.exec.compress.output=true;
SET mapred.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec;
```

### Use Partitioning

For large fact tables, partition by year:

```sql
CREATE TABLE fact_passenger_entry_exit_partitioned (
    entry_exit_id BIGINT,
    station_id INT,
    date_id INT,
    total_entry_exit BIGINT,
    estimated_entries BIGINT,
    estimated_exits BIGINT,
    record_type STRING,
    data_source STRING,
    created_at TIMESTAMP
)
PARTITIONED BY (year INT)
STORED AS PARQUET;

-- Load data with dynamic partitioning
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT INTO fact_passenger_entry_exit_partitioned PARTITION(year)
SELECT 
    f.*,
    d.year
FROM fact_passenger_entry_exit f
JOIN dim_date d ON f.date_id = d.date_id;
```

---

## 🎯 Common Operations

### Drop and Recreate Database

```bash
# WARNING: This deletes all tables and data references
hive -e "DROP DATABASE IF EXISTS uttam_tfl CASCADE;"
hive -f create_database.hql
hive -f create_tables.hql
```

### Refresh Table Metadata

If HDFS data changes:
```sql
USE uttam_tfl;
MSCK REPAIR TABLE dim_stations;
```

### Export Query Results

```bash
# Export to local file
hive -e "USE uttam_tfl; SELECT * FROM dim_stations;" > /tmp/dim_stations_export.csv

# Export to HDFS
hive -e "
USE uttam_tfl;
INSERT OVERWRITE DIRECTORY '/tmp/uttam/exports/dim_stations'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
SELECT * FROM dim_stations;
"
```

### Drop Single Table

```sql
USE uttam_tfl;
DROP TABLE IF EXISTS dim_stations;

-- Recreate from HDFS
-- Run relevant section from create_tables.hql
```

---

## 📊 Hive vs Spark SQL

Tables created in Hive are accessible from Spark SQL:

```python
# PySpark
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("TfL Analysis") \
    .enableHiveSupport() \
    .getOrCreate()

# Query Hive tables
df = spark.sql("""
    SELECT * 
    FROM uttam_tfl.dim_stations 
    WHERE has_night_tube = TRUE
""")

df.show()
```

```scala
// Scala Spark
val spark = SparkSession.builder()
  .appName("TfL Analysis")
  .enableHiveSupport()
  .getOrCreate()

val df = spark.sql("""
  SELECT s.station_name, SUM(f.total_entry_exit) as total
  FROM uttam_tfl.fact_passenger_entry_exit f
  JOIN uttam_tfl.dim_stations s ON f.station_id = s.station_id
  GROUP BY s.station_name
  ORDER BY total DESC
  LIMIT 10
""")

df.show()
```

---

## 📚 Additional Resources

- [Apache Hive Documentation](https://hive.apache.org/documentation/)
- [HiveQL Language Manual](https://cwiki.apache.org/confluence/display/Hive/LanguageManual)
- [Hive Performance Tuning](https://cwiki.apache.org/confluence/display/Hive/PerformanceTuning)
- [Spark SQL + Hive Integration](https://spark.apache.org/docs/latest/sql-data-sources-hive-tables.html)

---

## 🎓 Best Practices

1. ✅ **Use EXTERNAL tables** for data in HDFS
2. ✅ **Skip CSV headers** with `skip.header.line.count`
3. ✅ **Partition large tables** by year/month
4. ✅ **Convert to Parquet** for production
5. ✅ **Test queries on small tables** first
6. ✅ **Use meaningful table comments**
7. ✅ **Document column meanings**
8. ✅ **Regular ANALYZE TABLE** for statistics

---

## 📞 Support

For issues:
1. Check HDFS data exists
2. Verify Hive is running: `hive --version`
3. Check database: `hive -e "SHOW DATABASES;"`
4. Review logs: `/tmp/${USER}/hive.log`

**Project Repository:** https://github.com/uttamraj9/TFL_Project_Demo

---

*Last Updated: June 2, 2026*
