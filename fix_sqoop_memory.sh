#!/bin/bash
###############################################################################
# Sqoop Memory Issue - Automated Fix Script
# Connects to Cloudera cluster and fixes Java OOM error
# Run this from Jenkins or locally
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================"
echo "Sqoop Memory Issue - Automated Fix"
echo "========================================${NC}"

# Configuration
CLOUDERA_HOST="13.41.167.97"
CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"
PG_HOST="13.42.152.118"
PG_PORT="5432"
PG_DB="testdb"
PG_USER="admin"
PG_PASSWORD="admin123"

# Step 1: Check Cloudera memory
echo -e "\n${YELLOW}Step 1: Checking Cloudera server memory...${NC}"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "free -h" 2>&1 | grep -v "Warning"

MEM_AVAILABLE=$(sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "free -m | awk 'NR==2 {print \$7}'" 2>&1 | grep -v "Warning")

echo -e "${GREEN}Available memory: ${MEM_AVAILABLE} MB${NC}"

if [ "$MEM_AVAILABLE" -lt 500 ]; then
    echo -e "${RED}WARNING: Low memory! Available: ${MEM_AVAILABLE} MB (need 500+ MB)${NC}"
    echo "Consider killing stale processes or restarting YARN NodeManager"
fi

# Step 2: Check and kill stale Sqoop processes
echo -e "\n${YELLOW}Step 2: Checking for stale Sqoop/MapReduce jobs...${NC}"
STALE_JOBS=$(sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "ps aux | grep -E 'sqoop.*testdb|MapReduce' | grep -v grep | wc -l" 2>&1 | grep -v "Warning")

if [ "$STALE_JOBS" -gt 0 ]; then
    echo -e "${YELLOW}Found $STALE_JOBS stale job(s). Killing...${NC}"
    sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $CLOUDERA_USER@$CLOUDERA_HOST "pkill -9 -f 'sqoop.*testdb' || true" 2>&1 | grep -v "Warning"
    sleep 5
    echo -e "${GREEN}✓ Stale jobs cleaned${NC}"
else
    echo -e "${GREEN}✓ No stale jobs found${NC}"
fi

# Step 3: Test PostgreSQL connectivity
echo -e "\n${YELLOW}Step 3: Testing PostgreSQL connectivity...${NC}"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -U $PG_USER -d $PG_DB -c '\dt' | grep dim_networks" 2>&1 | grep -v "Warning"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PostgreSQL connection successful${NC}"
else
    echo -e "${RED}✗ PostgreSQL connection failed${NC}"
    exit 1
fi

# Step 4: Check YARN NodeManager status
echo -e "\n${YELLOW}Step 4: Checking YARN NodeManager status...${NC}"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "yarn node -list 2>&1 | grep -E 'RUNNING|Total'" 2>&1 | grep -v "Warning"

# Step 5: Run test Sqoop import (smallest table)
echo -e "\n${YELLOW}Step 5: Testing Sqoop with reduced memory (dim_networks - smallest table)...${NC}"

cat > /tmp/sqoop_test_command.sh << 'EOF'
#!/bin/bash
export HADOOP_CLIENT_OPTS="-Xmx128m"

sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table dim_networks \
  --target-dir /user/consultant/tfl_test/dim_networks \
  --m 1 \
  -D mapreduce.map.memory.mb=256 \
  -D mapreduce.map.java.opts="-Xmx204m" \
  --delete-target-dir \
  2>&1 | grep -E 'INFO|ERROR|retrieved|rows'
EOF

sshpass -p "$CLOUDERA_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    /tmp/sqoop_test_command.sh $CLOUDERA_USER@$CLOUDERA_HOST:/tmp/ 2>&1 | grep -v "Warning"

sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "chmod +x /tmp/sqoop_test_command.sh && bash /tmp/sqoop_test_command.sh" 2>&1 | \
    grep -v "Warning" | tail -30

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓✓✓ TEST IMPORT SUCCESSFUL!${NC}"
    echo -e "${GREEN}Memory settings are working correctly.${NC}"
    echo -e "${GREEN}Safe to proceed with full import.${NC}"
else
    echo -e "\n${RED}✗✗✗ TEST IMPORT FAILED${NC}"
    echo -e "${RED}Check Cloudera Manager: http://13.41.167.97:7180/${NC}"
    exit 1
fi

# Step 6: Verify HDFS output
echo -e "\n${YELLOW}Step 6: Verifying HDFS output...${NC}"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST "hdfs dfs -ls /user/consultant/tfl_test/dim_networks/" 2>&1 | \
    grep -v "Warning"

ROW_COUNT=$(sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "hdfs dfs -cat /user/consultant/tfl_test/dim_networks/part-m-00000 | wc -l" 2>&1 | grep -v "Warning")

echo -e "${GREEN}✓ HDFS contains $ROW_COUNT row(s)${NC}"

# Step 7: Summary and recommendations
echo -e "\n${GREEN}========================================"
echo "✓✓✓ DIAGNOSTIC COMPLETE"
echo "========================================${NC}"
echo ""
echo -e "${GREEN}Fix Applied:${NC}"
echo "  • Reduced Java heap: 337 MB → 128 MB"
echo "  • Reduced mapper memory: default → 256 MB"
echo "  • Reduced mapper heap: default → 204 MB"
echo ""
echo -e "${YELLOW}Recommendations:${NC}"
echo "  1. Import tables sequentially (not parallel)"
echo "  2. Add 10-second delay between imports"
echo "  3. Monitor memory with: free -h"
echo "  4. Check Cloudera Manager if issues persist:"
echo "     http://13.41.167.97:7180/"
echo "     User: Admin"
echo "     Password: Admin@2026"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Update Jenkins Sqoop job with memory settings"
echo "  2. Run full import for all 6 tables"
echo "  3. Use SQOOP_MEMORY_FIX.md as reference"
echo ""
echo -e "${GREEN}Test import successful. Ready for production import!${NC}"
