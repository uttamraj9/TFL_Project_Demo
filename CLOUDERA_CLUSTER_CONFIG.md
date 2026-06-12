# Cloudera Cluster Configuration

**Cluster:** http://13.41.167.97:7180/
**Credentials:** admin / Admin@2026

---

## 🖥️ Cluster Topology (Retrieved from CM API)

### Kafka Brokers (4 brokers)
```
ip-172-31-6-42.eu-west-2.compute.internal:9092   [STARTED]
ip-172-31-3-251.eu-west-2.compute.internal:9092  [STARTED]
ip-172-31-3-85.eu-west-2.compute.internal:9092   [STARTED]
ip-172-31-12-74.eu-west-2.compute.internal:9092  [STARTED]
```

### HBase Servers
```
MASTER:        ip-172-31-12-74.eu-west-2.compute.internal [STARTED]
REGIONSERVER:  ip-172-31-6-42.eu-west-2.compute.internal  [STARTED]
REGIONSERVER:  ip-172-31-12-74.eu-west-2.compute.internal [STARTED]
REGIONSERVER:  ip-172-31-3-85.eu-west-2.compute.internal  [STARTED]
```

---

## 🔧 Cloudera Manager API Commands

### Get Kafka Brokers
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka/roles' | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
    if item.get('type') == 'KAFKA_BROKER':
        print(item.get('hostRef', {}).get('hostname', 'unknown') + ':9092')
"
```

### Get HBase Servers
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase/roles' | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('items', []):
    role = item.get('type', '')
    if 'MASTER' in role or 'REGIONSERVER' in role:
        print(f\"{role}: {item.get('hostRef', {}).get('hostname', 'unknown')}\")
"
```

### Check Kafka Status
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka' | \
  python3 -c "import json,sys; print('Kafka:', json.load(sys.stdin)['serviceState'])"
```

### Check HBase Status
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase' | \
  python3 -c "import json,sys; print('HBase:', json.load(sys.stdin)['serviceState'])"
```

### Start Kafka Service
```bash
curl -X POST -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka/commands/start'
```

### Start HBase Service
```bash
curl -X POST -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase/commands/start'
```

### List All Services
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services' | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for svc in data.get('items', []):
    print(f\"{svc['name']}: {svc['serviceState']}\")
"
```

### List All Hosts
```bash
curl -s -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/hosts' | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for host in data.get('items', []):
    print(f\"{host['hostname']} - {host.get('ipAddress', 'N/A')}\")
"
```

---

## 📝 CM API Documentation

### Base URL
```
http://13.41.167.97:7180/api/v40
```

### Authentication
```
Username: admin
Password: Admin@2026
```

### Common Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/clusters` | GET | List all clusters |
| `/clusters/{cluster}/services` | GET | List services in cluster |
| `/clusters/{cluster}/services/{service}` | GET | Service details |
| `/clusters/{cluster}/services/{service}/roles` | GET | Service roles (brokers, etc.) |
| `/clusters/{cluster}/services/{service}/commands/start` | POST | Start service |
| `/clusters/{cluster}/services/{service}/commands/stop` | POST | Stop service |
| `/clusters/{cluster}/services/{service}/commands/restart` | POST | Restart service |
| `/hosts` | GET | List all hosts |
| `/hosts/{hostId}/metrics` | GET | Host metrics |

---

## 🌐 AWS CLI Integration

### Get EC2 Instance IPs
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*cloudera*" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,State.Name]' \
  --output table
```

### Get Security Groups
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*cloudera*" \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp]]' \
  --output table
```

### Check EC2 Instance Status
```bash
aws ec2 describe-instance-status \
  --instance-ids i-xxxxxxxxx \
  --query 'InstanceStatuses[*].[InstanceId,InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]' \
  --output table
```

---

## 🔗 Configuration in Code

### Producer (send_data_to_kafka_simple.py)
```python
kafka_brokers = [
    "ip-172-31-6-42.eu-west-2.compute.internal:9092",
    "ip-172-31-3-251.eu-west-2.compute.internal:9092",
    "ip-172-31-3-85.eu-west-2.compute.internal:9092",
    "ip-172-31-12-74.eu-west-2.compute.internal:9092"
]
```

### Consumer (read_from_kafka_hbase.py)
```python
# Kafka brokers (comma-separated)
kafka_brokers = "ip-172-31-6-42.eu-west-2.compute.internal:9092,ip-172-31-3-251.eu-west-2.compute.internal:9092,ip-172-31-3-85.eu-west-2.compute.internal:9092,ip-172-31-12-74.eu-west-2.compute.internal:9092"

# HBase Master
spark.config("spark.hbase.host", "ip-172-31-12-74.eu-west-2.compute.internal")
```

### Jenkinsfile
```groovy
environment {
    KAFKA_BROKERS = 'ip-172-31-6-42.eu-west-2.compute.internal:9092,ip-172-31-3-251.eu-west-2.compute.internal:9092,ip-172-31-3-85.eu-west-2.compute.internal:9092,ip-172-31-12-74.eu-west-2.compute.internal:9092'
    HBASE_MASTER = 'ip-172-31-12-74.eu-west-2.compute.internal'
    CM_API = 'http://13.41.167.97:7180/api/v40'
    CM_USER = 'admin'
    CM_PASS = 'Admin@2026'
}
```

---

## ✅ Updated Files

All scripts now use the correct broker addresses from CM API:
- ✅ src/realtime/send_data_to_kafka_simple.py (4 brokers)
- ✅ src/realtime/read_from_kafka_hbase.py (4 brokers + correct HBase master)
- ✅ src/realtime/Jenkinsfile (needs update)

---

## 🎯 Verification Commands

### Test Kafka Connection
```bash
# From edge node (consultant@13.41.167.97)
kafka-console-consumer \
    --bootstrap-server ip-172-31-6-42.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 1
```

### Test HBase Connection
```bash
# From any cluster node
hbase shell
> list
> status 'detailed'
> exit
```

---

**Last Updated:** 2026-06-12 (via Cloudera Manager API)
**Cluster:** Cluster 1
**CM Version:** API v40
