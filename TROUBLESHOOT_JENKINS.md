# Jenkins Job Troubleshooting Guide

## 🔍 Common Failures & Fixes

### Failure 1: Git Clone Error
**Error Message:**
```
fatal: could not read Username for 'https://github.com'
```

**Fix:** The Jenkinsfile needs to be updated to use consultant user credentials.

**Solution:** Update the Jenkinsfile SSH settings.

---

### Failure 2: SSH Connection Failed
**Error Message:**
```
Permission denied (publickey,password)
```

**Fix:** Jenkins needs SSH credentials configured.

**Solution:**
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Add new credentials:
   - Username: consultant
   - Password: WelcomeItc@2026
   - ID: consultant-ssh

Then update Jenkinsfile to use these credentials.

---

### Failure 3: Python Module Not Found
**Error Message:**
```
ModuleNotFoundError: No module named 'kafka'
or
ModuleNotFoundError: No module named 'pyspark'
```

**Fix:** Dependencies need to be installed on remote server.

**Solution via SSH:**
```bash
ssh consultant@13.41.167.97
pip3 install --user kafka-python requests pyspark
```

---

### Failure 4: Kafka Connection Failed
**Error Message:**
```
NoBrokersAvailable
or
Connection refused to ip-172-31-8-235:9092
```

**Fix:** Either Kafka is down or network issue.

**Solution:**
```bash
# Check Kafka status via CM API
curl -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka'

# If stopped, start it via CM UI or API
```

---

### Failure 5: HBase Connection Failed
**Error Message:**
```
Failed to create HBase table
or
HBase shell command not found
```

**Fix:** HBase not accessible or not started.

**Solution:**
```bash
# Check HBase status
curl -u 'admin:Admin@2026' \
  'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase'

# Start HBase if needed via CM
```

---

## 🚨 LIKELY ISSUE: Jenkinsfile SSH Problem

The Jenkinsfile uses `sshagent` which requires credentials configured in Jenkins.

### Quick Fix: Use Simplified Jenkinsfile

Replace the current Jenkinsfile with this simpler version:

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'MODE',
            choices: ['producer', 'consumer_hbase', 'both'],
            description: 'Run producer, HBase consumer, or both'
        )
        string(
            name: 'DURATION_MINUTES',
            defaultValue: '5',
            description: 'How long to run (minutes)'
        )
    }

    environment {
        REMOTE_HOST = '13.41.167.97'
        REMOTE_USER = 'consultant'
        PROJECT_DIR = '/home/consultant/uttam/TFL_Project_Demo'
        
        KAFKA_BROKERS = 'ip-172-31-8-235.eu-west-2.compute.internal:9092'
        KAFKA_TOPIC = 'tfl_arrivals'
        HBASE_TABLE = 'tfl_arrivals'
    }

    stages {
        stage('Setup') {
            steps {
                echo "=== TfL Real-time Pipeline ==="
                echo "MODE: ${params.MODE}"
                echo "DURATION: ${params.DURATION_MINUTES} minutes"
            }
        }

        stage('Deploy & Run') {
            steps {
                script {
                    // Using sshpass directly (simpler than sshagent)
                    sh '''
                        sshpass -p "WelcomeItc@2026" ssh -o StrictHostKeyChecking=no consultant@13.41.167.97 << 'ENDSSH'
                            set -e
                            
                            # Deploy project
                            cd /home/consultant/uttam
                            [ -d "TFL_Project_Demo" ] && cd TFL_Project_Demo && git pull || git clone https://github.com/uttamraj9/TFL_Project_Demo.git && cd TFL_Project_Demo
                            
                            # Install dependencies
                            pip3 install --user kafka-python requests 2>/dev/null || true
                            
                            # Create HBase table
                            echo -e "disable 'tfl_arrivals'\\ndrop 'tfl_arrivals'\\ncreate 'tfl_arrivals', 'cf'\\nexit" | hbase shell 2>/dev/null || true
                            
                            # Navigate to scripts
                            cd src/realtime
                            
                            # Kill old processes
                            pkill -f send_data_to_kafka_simple.py 2>/dev/null || true
                            pkill -f read_from_kafka_hbase.py 2>/dev/null || true
                            
                            # Start producer
                            nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &
                            sleep 15
                            
                            # Start consumer
                            nohup spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 read_from_kafka_hbase.py > consumer.log 2>&1 &
                            
                            # Wait for duration
                            sleep ''' + "${params.DURATION_MINUTES}" + '''m
                            
                            # Show results
                            echo "=== Producer Log ==="
                            tail -20 producer.log
                            
                            echo "=== Consumer Log ==="
                            tail -20 consumer.log
                            
                            echo "=== HBase Data ==="
                            echo "scan 'tfl_arrivals', {LIMIT => 5}" | hbase shell 2>/dev/null | grep -A 15 "ROW"
                            echo "count 'tfl_arrivals'" | hbase shell 2>/dev/null | grep "row(s)"
                            
                            # Stop processes
                            pkill -f send_data_to_kafka_simple.py 2>/dev/null || true
                            pkill -f read_from_kafka_hbase.py 2>/dev/null || true
ENDSSH
                    '''
                }
            }
        }
    }
}
```

---

## 🛠️ Alternative: Run Manually via SSH

If Jenkins continues to fail, run the pipeline manually:

```bash
# 1. SSH to server
ssh consultant@13.41.167.97

# 2. Run this complete script
cd /home/consultant/uttam
[ -d "TFL_Project_Demo" ] && cd TFL_Project_Demo && git pull || git clone https://github.com/uttamraj9/TFL_Project_Demo.git && cd TFL_Project_Demo

# Install dependencies
pip3 install --user kafka-python requests

# Create HBase table
echo -e "disable 'tfl_arrivals'\ndrop 'tfl_arrivals'\ncreate 'tfl_arrivals', 'cf'\nexit" | hbase shell

# Start producer
cd src/realtime
nohup python3 send_data_to_kafka_simple.py > producer.log 2>&1 &

# Wait 20 seconds
sleep 20

# Check producer
tail producer.log

# Start consumer
nohup spark-submit --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 read_from_kafka_hbase.py > consumer.log 2>&1 &

# Wait 2 minutes for data
sleep 120

# Check results
echo "=== Kafka Topic Messages ==="
/opt/cloudera/parcels/CDH/bin/kafka-console-consumer \
    --bootstrap-server ip-172-31-8-235.eu-west-2.compute.internal:9092 \
    --topic tfl_arrivals \
    --from-beginning \
    --max-messages 3 | python3 -m json.tool

echo "=== HBase Table Data ==="
hbase shell << EOF
scan 'tfl_arrivals', {LIMIT => 10}
count 'tfl_arrivals'
exit
EOF

# Stop processes
pkill -f send_data_to_kafka_simple.py
pkill -f read_from_kafka_hbase.py
```

---

## 📋 What Error Did You See?

To help you fix it, I need to know the specific error. Look for:

1. **Red text** in Console Output
2. **Error messages** like:
   - "Permission denied"
   - "Connection refused"
   - "Module not found"
   - "Command not found"
   - "Authentication failed"

**Copy the error message** and I'll provide the exact fix!

---

## 🎯 Fastest Way to See Results RIGHT NOW

Run these commands on your local machine:

```bash
ssh consultant@13.41.167.97 "cd /home/consultant/uttam/TFL_Project_Demo/src/realtime && python3 send_data_to_kafka_simple.py" &

sleep 30

ssh consultant@13.41.167.97 "hbase shell << EOF
scan 'tfl_arrivals', {LIMIT => 10}
exit
EOF"
```

This will show you data immediately without Jenkins!

---

**Tell me the exact error from Console Output and I'll fix it!** 🔧
