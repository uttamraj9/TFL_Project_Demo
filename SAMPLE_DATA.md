# Sample Data - Kafka Topic vs HBase Table

## 📨 What's in KAFKA Topic: `tfl_arrivals`

### Format: JSON Messages

Each message is a complete JSON object from TfL API:

```json
{
  "id": "1718211930123456",
  "operationType": 1,
  "vehicleId": "123",
  "naptanId": "940GZZLUVIC",
  "stationName": "Victoria",
  "lineId": "victoria",
  "lineName": "Victoria",
  "platformName": "Platform 1 - Northbound",
  "direction": "inbound",
  "bearing": "",
  "destinationNaptanId": "940GZZLUBXN",
  "destinationName": "Brixton",
  "timestamp": "2026-06-12T17:28:00Z",
  "timeToStation": 120,
  "currentLocation": "At Victoria",
  "towards": "Brixton",
  "expectedArrival": "2026-06-12T17:30:00Z",
  "timeToLive": "2026-06-12T17:31:00Z",
  "modeName": "tube",
  "timing": {
    "countdownServerAdjustment": "00:00:00",
    "source": "0001-01-01T00:00:00",
    "insert": "0001-01-01T00:00:00",
    "read": "2026-06-12T17:27:55.123Z",
    "sent": "2026-06-12T17:28:00.456Z",
    "received": "0001-01-01T00:00:00"
  }
}
```

### Multiple Messages Example:

```json
[
  {
    "stationName": "Victoria",
    "lineName": "Victoria",
    "towards": "Brixton",
    "timeToStation": 120,
    "platformName": "Platform 1"
  },
  {
    "stationName": "Victoria",
    "lineName": "Victoria",
    "towards": "Walthamstow Central",
    "timeToStation": 180,
    "platformName": "Platform 2"
  },
  {
    "stationName": "Green Park",
    "lineName": "Victoria",
    "towards": "Brixton",
    "timeToStation": 90,
    "platformName": "Platform 1"
  }
]
```

### Characteristics:
- **Raw format:** Complete JSON from TfL API
- **Message size:** ~800-1200 bytes per message
- **Frequency:** ~9-15 messages every 10 seconds
- **Retention:** Kafka default (7 days)
- **Use case:** Real-time streaming, event sourcing

---

## 🗄️ What's in HBASE Table: `tfl_arrivals`

### Format: Structured Rows with Columns

Each Kafka message becomes **one row** in HBase with structured columns.

### Row Key Format:
```
{naptanId}_{lineId}_{direction}_{timestamp}
```

**Example:**
```
940GZZLUVIC_victoria_inbound_1718211930
```

### Column Family: `cf`

### Sample Row in HBase:

```
hbase> scan 'tfl_arrivals', {LIMIT => 1}

ROW                                          COLUMN+CELL
940GZZLUVIC_victoria_inbound_1718211930     column=cf:currentLocation, timestamp=1718211930000, value=At Victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:destinationName, timestamp=1718211930000, value=Brixton
940GZZLUVIC_victoria_inbound_1718211930     column=cf:destinationNaptanId, timestamp=1718211930000, value=940GZZLUBXN
940GZZLUVIC_victoria_inbound_1718211930     column=cf:direction, timestamp=1718211930000, value=inbound
940GZZLUVIC_victoria_inbound_1718211930     column=cf:expectedArrival, timestamp=1718211930000, value=2026-06-12T17:30:00Z
940GZZLUVIC_victoria_inbound_1718211930     column=cf:id, timestamp=1718211930000, value=1718211930123456
940GZZLUVIC_victoria_inbound_1718211930     column=cf:lineId, timestamp=1718211930000, value=victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:lineName, timestamp=1718211930000, value=Victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:modeName, timestamp=1718211930000, value=tube
940GZZLUVIC_victoria_inbound_1718211930     column=cf:naptanId, timestamp=1718211930000, value=940GZZLUVIC
940GZZLUVIC_victoria_inbound_1718211930     column=cf:platformName, timestamp=1718211930000, value=Platform 1 - Northbound
940GZZLUVIC_victoria_inbound_1718211930     column=cf:stationName, timestamp=1718211930000, value=Victoria
940GZZLUVIC_victoria_inbound_1718211930     column=cf:timeToLive, timestamp=1718211930000, value=2026-06-12T17:31:00Z
940GZZLUVIC_victoria_inbound_1718211930     column=cf:timeToStation, timestamp=1718211930000, value=120
940GZZLUVIC_victoria_inbound_1718211930     column=cf:timestamp, timestamp=1718211930000, value=2026-06-12T17:28:00Z
940GZZLUVIC_victoria_inbound_1718211930     column=cf:towards, timestamp=1718211930000, value=Brixton
940GZZLUVIC_victoria_inbound_1718211930     column=cf:vehicleId, timestamp=1718211930000, value=123

1 row(s)
```

### Multiple Rows Example:

```
ROW                                          KEY COLUMNS
──────────────────────────────────────────────────────────────────────
940GZZLUVIC_victoria_inbound_1718211930     Victoria → Brixton (120s)
940GZZLUVIC_victoria_outbound_1718211950    Victoria → Walthamstow (180s)
940GZZLUGPK_victoria_inbound_1718211940     Green Park → Brixton (90s)
940GZZLUGPK_victoria_outbound_1718211945    Green Park → Walthamstow (150s)
940GZZLUKSX_victoria_inbound_1718211935     King's Cross → Brixton (240s)
```

### Characteristics:
- **Structured format:** Each field is a separate column
- **Row key:** Enables fast lookups by station/line/direction/time
- **Storage:** Compressed columnar storage
- **Retention:** Permanent (until deleted)
- **Use case:** Analytics, historical queries, dashboards

---

## 🔄 Data Transformation Flow

### 1. TfL API Response (Victoria Line arrivals)
```json
[
  {"stationName": "Victoria", "timeToStation": 120, ...},
  {"stationName": "Victoria", "timeToStation": 180, ...},
  {"stationName": "Green Park", "timeToStation": 90, ...}
]
```

### 2. Producer → Kafka (1 message per arrival)
```
Topic: tfl_arrivals
Message 1: {"stationName": "Victoria", "timeToStation": 120, ...}
Message 2: {"stationName": "Victoria", "timeToStation": 180, ...}
Message 3: {"stationName": "Green Park", "timeToStation": 90, ...}
```

### 3. Spark Streaming → HBase (1 row per message)
```
Table: tfl_arrivals
Row 1: 940GZZLUVIC_victoria_inbound_1718211930
Row 2: 940GZZLUVIC_victoria_outbound_1718211950
Row 3: 940GZZLUGPK_victoria_inbound_1718211940
```

---

## 📊 Data Comparison

| Aspect | Kafka Topic | HBase Table |
|--------|-------------|-------------|
| **Format** | JSON (nested) | Columnar (flat) |
| **Access** | Sequential (offset-based) | Random (key-based) |
| **Query** | Stream processing | Point/range queries |
| **Size** | ~1KB per message | ~500 bytes per row |
| **Speed** | Write: Very fast | Read: Very fast |
| **Retention** | Temporary (days) | Permanent |
| **Use Case** | Real-time streaming | Analytics/reporting |

---

## 🎯 Example Queries

### Kafka Consumer (Python)
```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer('tfl_arrivals',
    bootstrap_servers=['ip-172-31-8-235:9092'],
    value_deserializer=lambda m: json.loads(m.decode('utf-8')))

for message in consumer:
    arrival = message.value
    print(f"{arrival['stationName']} → {arrival['towards']}: {arrival['timeToStation']}s")
```

### HBase Shell
```bash
# Get all arrivals for Victoria station
scan 'tfl_arrivals', {STARTROW => '940GZZLUVIC_', STOPROW => '940GZZLUVIC`'}

# Get specific arrival
get 'tfl_arrivals', '940GZZLUVIC_victoria_inbound_1718211930'

# Count all records
count 'tfl_arrivals'
```

---

## 🔍 Real Data Example (After Running)

### Command to See Kafka Data:
```bash
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 3
```

### Command to See HBase Data:
```bash
hbase shell
> scan 'tfl_arrivals', {LIMIT => 5}
> count 'tfl_arrivals'
```

---

## 📈 Expected Data Volume (5-minute run)

| Metric | Kafka | HBase |
|--------|-------|-------|
| **API Calls** | 30 | - |
| **Messages/Rows** | ~300-450 | ~300-450 |
| **Data Size** | ~300-500 KB | ~150-250 KB |
| **Unique Stations** | ~15-20 | ~15-20 |
| **Lines** | Victoria | Victoria |

---

## 🚀 To See Real Data

Run these commands on the server (see [MANUAL_RUN_COMMANDS.md](./MANUAL_RUN_COMMANDS.md)):

```bash
# 1. SSH to server
ssh consultant@13.41.167.97

# 2. Start pipeline
cd /home/consultant/uttam/TFL_Project_Demo/src/realtime
python3 send_data_to_kafka_simple.py &  # Producer
spark-submit read_from_kafka_hbase.py &   # Consumer

# 3. Check Kafka
kafka-console-consumer --topic tfl_arrivals --max-messages 5

# 4. Check HBase
hbase shell
> scan 'tfl_arrivals', {LIMIT => 10}
```

**You'll see the actual live TfL data!** 🚇
