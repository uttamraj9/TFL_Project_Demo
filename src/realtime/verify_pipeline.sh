#!/bin/bash
# TfL Real-time Pipeline Verification Script
# This script verifies the pipeline can connect and run

echo "========================================="
echo "TfL Real-time Pipeline - Pre-flight Check"
echo "========================================="
echo ""

REMOTE_HOST="13.41.167.97"
REMOTE_USER="ec2-user"
SSH_KEY="$HOME/Desktop/Training/test_key.pem"
PROJECT_DIR="/home/ec2-user/TFL_Project_Demo"

echo "1. Testing SSH Connection..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'SSH: ✅ Connected'" || {
    echo "❌ SSH connection failed"
    exit 1
}
echo ""

echo "2. Checking Project Directory..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "ls -la $PROJECT_DIR/src/realtime/ 2>/dev/null || echo 'Directory not found yet'"
echo ""
echo ""

echo "3. Checking Cloudera Manager API..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" \
    "curl -s -u 'admin:Admin@2026' 'http://13.41.167.97:7180/api/v40/clusters' | python3 -c \"import json,sys; clusters=json.load(sys.stdin); print('CM API: ✅ Reachable - Cluster:', clusters['items'][0]['displayName'] if clusters['items'] else 'None')\"" || {
    echo "⚠️  Cloudera Manager API check failed (may need to run from cluster)"
}
echo ""

echo "4. Checking Kafka Service Status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" \
    "curl -s -u 'admin:Admin@2026' 'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/kafka' | python3 -c \"import json,sys; svc=json.load(sys.stdin); print('Kafka:', svc.get('serviceState', 'UNKNOWN'))\" 2>/dev/null || echo 'Kafka: Check via Jenkins'"
echo ""

echo "5. Checking HBase Service Status..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" \
    "curl -s -u 'admin:Admin@2026' 'http://13.41.167.97:7180/api/v40/clusters/Cluster%201/services/hbase' | python3 -c \"import json,sys; svc=json.load(sys.stdin); print('HBase:', svc.get('serviceState', 'UNKNOWN'))\" 2>/dev/null || echo 'HBase: Check via Jenkins'"
echo ""

echo "6. Testing TfL API Connection..."
curl -s "https://api.tfl.gov.uk/Line/victoria/Arrivals?stopPointId=940GZZLUVIC" | python3 -c "import json,sys; data=json.load(sys.stdin); print(f'TfL API: ✅ Responding - {len(data)} arrivals found')" || {
    echo "❌ TfL API not accessible"
    exit 1
}
echo ""

echo "========================================="
echo "✅ Pre-flight Check Complete!"
echo "========================================="
echo ""
echo "Next Steps:"
echo "1. Open Jenkins: http://51.24.13.205:8081/"
echo "2. Create Pipeline job named: TfL-Realtime-Pipeline"
echo "3. Configure Git SCM: https://github.com/uttamraj9/TFL_Project_Demo.git"
echo "4. Script Path: src/realtime/Jenkinsfile"
echo "5. Build with Parameters: MODE=both, DURATION_MINUTES=5"
echo ""
echo "Or run manually on remote server:"
echo "  ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST"
echo "  cd $PROJECT_DIR/src/realtime"
echo "  python3 send_data_to_kafka.py &"
echo "  python3 read_from_kafka_hbase.py"
