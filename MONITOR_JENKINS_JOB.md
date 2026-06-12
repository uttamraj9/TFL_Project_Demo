# Monitor Jenkins Job & View Results

## 🔍 How to Monitor the Running Job

### Step 1: Access Console Output

1. Open: http://51.24.13.205:8081/job/TfL-Realtime-Pipeline/
2. Click on the **build number** (e.g., #1, #2) in the left sidebar under "Build History"
3. Click **"Console Output"** on the left

### What You'll See (Stage by Stage):

```
Started by user [Your Name]
Cloning repository https://github.com/uttamraj9/TFL_Project_Demo.git

========================================
Stage 1: Check Services via CM API
========================================
Checking Kafka status...
Kafka: STARTED
Checking HBase status...
HBase: STARTED

========================================
Stage 2: Ensure Services Running
========================================
✓ Kafka is running
✓ HBase is running

========================================
Stage 3: Create HBase Table
========================================
Dropping existing table if present...
Creating HBase table 'tfl_arrivals'...
✓ Table created with column family 'cf'

========================================
Stage 4: Run Producer
========================================
MODE: both - Starting producer
Running: python3 send_data_to_kafka.py
Producer started in background
Duration: 5 minutes

Producer Output:
[2026-06-12 18:30:00] Starting TfL Kafka Producer...
[2026-06-12 18:30:00] Fetching from TfL API...
[2026-06-12 18:30:01] Fetched 12 arrival records
[2026-06-12 18:30:01] ✓ Sent 12 messages to Kafka topic: tfl_arrivals
[2026-06-12 18:30:10] Fetching from TfL API...
[2026-06-12 18:30:11] Fetched 15 arrival records
[2026-06-12 18:30:11] ✓ Sent 15 messages to Kafka topic: tfl_arrivals
...

========================================
Stage 5: Run HBase Consumer
========================================
MODE: both - Starting consumer
Running: spark-submit read_from_kafka_hbase.py
Consumer started in background

Consumer Output:
Starting Spark Structured Streaming...
Reading from Kafka: ip-172-31-8-235:9092,ip-172-31-14-3:9092
Topic: tfl_arrivals
Writing to HBase table: tfl_arrivals

Batch 0: Processing 12 rows
Writing to HBase...
✓ Batch 0: 12 rows written

Batch 1: Processing 15 rows
Writing to HBase...
✓ Batch 1: 15 rows written

Batch 2: Processing 13 rows
Writing to HBase...
✓ Batch 2: 13 rows written
...

========================================
Stage 6: Verify Data
========================================
Scanning HBase table for sample data...

ROW                                          COLUMN+CELL
940GZZLUVIC_victoria_inbound_1718212800     column=cf:destinationName, value=Brixton
940GZZLUVIC_victoria_inbound_1718212800     column=cf:expectedArrival, value=2026-06-12T18:32:10Z
940GZZLUVIC_victoria_inbound_1718212800     column=cf:lineName, value=Victoria
940GZZLUVIC_victoria_inbound_1718212800     column=cf:platformName, value=Platform 1
940GZZLUVIC_victoria_inbound_1718212800     column=cf:stationName, value=Victoria
940GZZLUVIC_victoria_inbound_1718212800     column=cf:timeToStation, value=120
940GZZLUVIC_victoria_inbound_1718212800     column=cf:towards, value=Brixton

5 rows shown

Counting total records...
✓ Total records in HBase: 327 row(s)

========================================
Pipeline Completed Successfully!
========================================
Duration: 5 minutes
Kafka Messages: ~30 API calls
HBase Records: 327 rows
Status: SUCCESS
```

---

## 📊 Understanding the Results

### Stage 4 Output (Producer):
- **What it shows:** API calls to TfL every 10 seconds
- **Key metrics:** 
  - Number of arrivals fetched per call (usually 9-15)
  - Messages sent to Kafka
  - Any errors (connection issues, API failures)

### Stage 5 Output (Consumer):
- **What it shows:** Spark Streaming batches
- **Key metrics:**
  - Batch number
  - Rows processed per batch
  - Rows written to HBase
  - Processing time per batch

### Stage 6 Output (Verification):
- **What it shows:** Actual data in HBase
- **Key metrics:**
  - Sample rows (first 5-10)
  - Total record count
  - Data structure (columns and values)

---

## 🎯 Expected Results (5-minute run)

| Metric | Expected Value |
|--------|----------------|
| **API Calls** | ~30 (1 every 10 seconds) |
| **Kafka Messages** | 270-450 messages |
| **HBase Rows** | 270-450 rows |
| **Spark Batches** | 5-10 batches |
| **Unique Stations** | 15-20 stations |
| **Lines** | Victoria line only |
| **Build Status** | SUCCESS ✓ |

---

## 🔍 How to Verify Results After Job Completes

### Option 1: SSH to Server and Check HBase

```bash
ssh consultant@13.41.167.97
# Password: WelcomeItc@2026

hbase shell
```

In HBase shell:
```
# See sample data
scan 'tfl_arrivals', {LIMIT => 10}

# Count total records
count 'tfl_arrivals'

# Get specific station's arrivals
scan 'tfl_arrivals', {STARTROW => '940GZZLUVIC_', STOPROW => '940GZZLUVIC`', LIMIT => 5}

# Exit
exit
```

### Option 2: Check Kafka Messages

```bash
ssh consultant@13.41.167.97

# Count messages in topic
/opt/cloudera/parcels/CDH/bin/kafka-run-class kafka.tools.GetOffsetShell \
    --broker-list ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals

# Read sample messages
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 5 | python3 -m json.tool
```

---

## 📸 Sample HBase Output

```
hbase> scan 'tfl_arrivals', {LIMIT => 3}

ROW                                          COLUMN+CELL
940GZZLUBXN_victoria_inbound_1718212800     column=cf:currentLocation, value=Between Brixton and Stockwell
940GZZLUBXN_victoria_inbound_1718212800     column=cf:destinationName, value=Walthamstow Central
940GZZLUBXN_victoria_inbound_1718212800     column=cf:direction, value=inbound
940GZZLUBXN_victoria_inbound_1718212800     column=cf:expectedArrival, value=2026-06-12T18:35:30Z
940GZZLUBXN_victoria_inbound_1718212800     column=cf:lineName, value=Victoria
940GZZLUBXN_victoria_inbound_1718212800     column=cf:platformName, value=Platform 1
940GZZLUBXN_victoria_inbound_1718212800     column=cf:stationName, value=Brixton
940GZZLUBXN_victoria_inbound_1718212800     column=cf:timeToStation, value=180
940GZZLUBXN_victoria_inbound_1718212800     column=cf:towards, value=Walthamstow Central
940GZZLUBXN_victoria_inbound_1718212800     column=cf:vehicleId, value=245

940GZZLUGPK_victoria_inbound_1718212815     column=cf:destinationName, value=Brixton
940GZZLUGPK_victoria_inbound_1718212815     column=cf:direction, value=inbound
940GZZLUGPK_victoria_inbound_1718212815     column=cf:expectedArrival, value=2026-06-12T18:33:45Z
940GZZLUGPK_victoria_inbound_1718212815     column=cf:lineName, value=Victoria
940GZZLUGPK_victoria_inbound_1718212815     column=cf:platformName, value=Platform 1
940GZZLUGPK_victoria_inbound_1718212815     column=cf:stationName, value=Green Park
940GZZLUGPK_victoria_inbound_1718212815     column=cf:timeToStation, value=105
940GZZLUGPK_victoria_inbound_1718212815     column=cf:towards, value=Brixton
940GZZLUGPK_victoria_inbound_1718212815     column=cf:vehicleId, value=178

940GZZLUVIC_victoria_outbound_1718212820    column=cf:destinationName, value=Walthamstow Central
940GZZLUVIC_victoria_outbound_1718212820    column=cf:direction, value=outbound
940GZZLUVIC_victoria_outbound_1718212820    column=cf:expectedArrival, value=2026-06-12T18:36:00Z
940GZZLUVIC_victoria_outbound_1718212820    column=cf:lineName, value=Victoria
940GZZLUVIC_victoria_outbound_1718212820    column=cf:platformName, value=Platform 2
940GZZLUVIC_victoria_outbound_1718212820    column=cf:stationName, value=Victoria
940GZZLUVIC_victoria_outbound_1718212820    column=cf:timeToStation, value=220
940GZZLUVIC_victoria_outbound_1718212820    column=cf:towards, value=Walthamstow Central
940GZZLUVIC_victoria_outbound_1718212820    column=cf:vehicleId, value=312

3 row(s)
```

---

## 🎯 Quick Checks

### Is the job running?
Look at the build history in Jenkins - you'll see:
- 🔵 **Blue pulsing icon** = Running
- ✓ **Green checkmark** = Success
- ✗ **Red X** = Failed

### How long will it take?
- **DURATION_MINUTES=5** → ~5-6 minutes total
- Stages 1-3: ~1 minute (setup)
- Stages 4-5: 5 minutes (running pipeline)
- Stage 6: ~30 seconds (verification)

### Where to see errors?
- **Console Output** shows all errors in real-time
- Common issues:
  - Kafka connection failed → Check CM
  - HBase write error → Check HBase service
  - TfL API timeout → Retry, API might be slow

---

## 🚀 What to Do Now

1. **Click on your build** (#1, #2, etc.) in the left sidebar
2. **Click "Console Output"**
3. **Watch it run** - you'll see stages complete one by one
4. **Wait for completion** (~6 minutes)
5. **Scroll to bottom** to see final verification results

After it completes, follow **"Option 1: SSH to Server"** above to see the actual data in HBase!

---

## 📝 Build Again?

To run another build:
1. Go back to: http://51.24.13.205:8081/job/TfL-Realtime-Pipeline/
2. Click **"Build with Parameters"**
3. Change duration if desired (e.g., 10 minutes for more data)
4. Click **"Build"**

Each run will:
- Drop and recreate the HBase table (fresh start)
- Collect new real-time data
- Add ~300-500 rows per 5-minute run

---

**Right now:** Open the Console Output and watch your pipeline run! 🎉
