# TfL Data Warehouse - Jenkins Pipelines Ready

**Status:** ✅ All pipelines configured and ready to run

---

## 🔗 Cluster Details

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **Jenkins** | http://51.24.13.205:8081/ | consultant | WelcomeItc@2026 |
| **Cloudera Manager** | http://13.41.167.97:7180 | admin | Admin@2026 |
| **Hue** | http://13.41.167.97:8888 | admin | Admin@2026 |
| **YARN ResourceManager** | http://13.41.167.97:8088 | — | — |
| **Spark History** | http://13.41.167.97:18088 | — | — |

**SSH Access:**
```bash
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97
```

---

## 📋 Available Pipelines

### 1. Complete ETL Pipeline
**Jenkinsfile:** `Jenkinsfile_Complete_ETL`

**What it does:**
- Exports all 6 tables from PostgreSQL
- Loads to HDFS: `/tmp/uttam/tfl_data/`
- Creates Hive database: `uttam_tfl`
- Creates 6 external tables via beeline
- Runs verification queries

**Parameters:**
- `ETL_MODE`: full, sqoop_only, hive_only, verify_only
- `CLEAN_START`: true/false (delete existing data)
- `MAPPER_MEMORY`: 256 (MB)

**Tables:**
- dim_networks
- dim_lines
- dim_stations
- dim_date
- fact_station_lines
- fact_passenger_entry_exit

---

### 2. PySpark Analysis Pipeline
**Jenkinsfile:** `Jenkinsfile_Spark_Fixed`

**What it does:**
- Runs PySpark jobs on YARN
- Scripts: `simple_spark_wordcount.py`, `tfl_spark_analysis.py`
- Minimal resource usage (512M, 1 executor)

**Parameters:**
- `SPARK_SCRIPT`: simple_spark_wordcount.py or tfl_spark_analysis.py
- `RESOURCE_PROFILE`: minimal, standard, large

---

### 3. Real-time Streaming Pipeline
**Jenkinsfile:** `Jenkinsfile_Realtime_Pipeline`

**What it does:**
- Producer: Fetches TfL Victoria Line arrivals → Kafka
- Consumer: Reads from Kafka → Writes to HDFS
- Kafka Topic: `tfl_arrivals`
- Output: `/tmp/uttam/kafka/tfl_arrivals/data/`

**Parameters:**
- `MODE`: producer, consumer, both
- `DURATION_MINUTES`: 5 (default)

**Scripts:**
- `realtime_pipeline/src/send_data_to_kafka.py`
- `realtime_pipeline/src/read_from_kafka.py`

---

## 🚀 Quick Start

### Step 1: Create Jenkins Job

1. Go to: http://51.24.13.205:8081/
2. Login: consultant / WelcomeItc@2026
3. Click: "New Item"
4. Enter job name (e.g., `TfL_Complete_ETL`)
5. Select: "Pipeline"
6. Click: "OK"

### Step 2: Configure Pipeline

**Pipeline Section:**
- Definition: `Pipeline script from SCM`
- SCM: `Git`
- Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
- Branch: `*/main`
- Script Path: Choose one:
  - `Jenkinsfile_Complete_ETL`
  - `Jenkinsfile_Spark_Fixed`
  - `Jenkinsfile_Realtime_Pipeline`

### Step 3: Build

Click "Build with Parameters" and select options.

---

## 📊 Pipeline #1: Complete ETL

**Recommended for first run:**

```
ETL_MODE = full
CLEAN_START = true
MAPPER_MEMORY = 256
```

**What happens:**
1. Drops existing database/tables
2. Exports PostgreSQL tables to CSV
3. Uploads to HDFS
4. Creates Hive database: `uttam_tfl`
5. Creates 6 external tables
6. Verifies data and runs sample queries

**Expected Duration:** 5-10 minutes

**Verify Results:**
```bash
# Via Hue
http://13.41.167.97:8888
# Run: USE uttam_tfl; SHOW TABLES;

# Via beeline
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97
beeline -u 'jdbc:hive2://ip-172-31-12-74:10000/uttam_tfl'
SHOW TABLES;
SELECT * FROM dim_networks;
```

---

## 📊 Pipeline #2: PySpark Analysis

**Recommended parameters:**

```
SPARK_SCRIPT = simple_spark_wordcount.py
RESOURCE_PROFILE = minimal
```

**What happens:**
1. Deploys PySpark script to Cloudera
2. Runs spark-submit on YARN
3. Shows full output (word counts, dataframes, etc.)

**Expected Duration:** 2-3 minutes

---

## 📊 Pipeline #3: Real-time Streaming

**Recommended parameters:**

```
MODE = both
DURATION_MINUTES = 5
```

**What happens:**
1. Creates Kafka topic: `tfl_arrivals`
2. Producer: Fetches TfL API every 10 seconds → Kafka
3. Consumer: Reads from Kafka → Writes CSV to HDFS
4. Runs for 5 minutes then stops

**Expected Duration:** 5 minutes + setup time

**Verify Results:**
```bash
hdfs dfs -ls /tmp/uttam/kafka/tfl_arrivals/data/
hdfs dfs -cat /tmp/uttam/kafka/tfl_arrivals/data/*.csv | head -20
```

---

## 🔍 Monitoring

### YARN Applications
http://13.41.167.97:8088

Shows running Spark/MapReduce jobs

### Spark History
http://13.41.167.97:18088

Shows completed Spark jobs and metrics

### HDFS Browser (Hue)
http://13.41.167.97:8888

Navigate to Files → Browse HDFS

### Cloudera Manager
http://13.41.167.97:7180

Service health, logs, metrics

---

## 🛠️ Troubleshooting

### Pipeline Fails with OOM
- Reduce `MAPPER_MEMORY` to 128
- Use `RESOURCE_PROFILE=minimal` for Spark
- Check available memory: `free -h`

### HiveServer2 Connection Failed
- Check Cloudera Manager: http://13.41.167.97:7180
- Service: Hive on Tez
- Verify HiveServer2 running on: ip-172-31-12-74:10000

### Kafka Not Available
- Check Kafka brokers:
  - ip-172-31-8-235:9092
  - ip-172-31-14-3:9092
- Test: `nc -zv ip-172-31-8-235 9092`

### No Data in HDFS
- Check HDFS permissions
- Verify paths exist: `hdfs dfs -ls /tmp/uttam/`
- Check YARN logs via ResourceManager

---

## 📁 Project Structure

```
TFL_Project_Demo/
├── Jenkinsfile_Complete_ETL      # Main ETL pipeline
├── Jenkinsfile_Spark_Fixed        # PySpark analysis
├── Jenkinsfile_Realtime_Pipeline  # Kafka streaming
├── src/
│   ├── hive/
│   │   ├── 01_create_database.hql
│   │   └── 02_create_tables.hql
│   └── spark/
│       ├── simple_spark_wordcount.py
│       └── tfl_spark_analysis.py
├── realtime_pipeline/
│   └── src/
│       ├── send_data_to_kafka.py
│       └── read_from_kafka.py
└── Data/normalized/              # 6 CSV files (5,812 records)
```

---

## 🎯 Recommended Execution Order

1. **First Run: Complete ETL Pipeline**
   ```
   Job: TfL_Complete_ETL
   Jenkinsfile: Jenkinsfile_Complete_ETL
   Parameters: ETL_MODE=full, CLEAN_START=true
   Result: Database + 6 tables with data
   ```

2. **Second Run: PySpark Analysis**
   ```
   Job: TfL_Spark_Analysis
   Jenkinsfile: Jenkinsfile_Spark_Fixed
   Parameters: SPARK_SCRIPT=simple_spark_wordcount.py
   Result: Spark job output visible
   ```

3. **Third Run: Real-time Streaming**
   ```
   Job: TfL_Realtime_Streaming
   Jenkinsfile: Jenkinsfile_Realtime_Pipeline
   Parameters: MODE=both, DURATION_MINUTES=5
   Result: Real-time data in HDFS
   ```

---

## ✅ Success Criteria

### ETL Pipeline Success:
- ✅ Database `uttam_tfl` exists
- ✅ 6 tables created
- ✅ All tables have data (row count > 0)
- ✅ Can query in Hue/beeline

### Spark Pipeline Success:
- ✅ Job shows "COMPLETED SUCCESSFULLY"
- ✅ Word counts or dataframe output visible
- ✅ YARN application completed

### Streaming Pipeline Success:
- ✅ Kafka topic `tfl_arrivals` created
- ✅ CSV files in `/tmp/uttam/kafka/tfl_arrivals/data/`
- ✅ Files contain TfL arrival data

---

**All pipelines ready to run!** 🚀
