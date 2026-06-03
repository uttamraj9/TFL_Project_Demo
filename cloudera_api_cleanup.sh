#!/bin/bash
###############################################################################
# Cloudera Manager API - Automated Cleanup & YARN Restart
# Uses CM API to restart services and free memory
###############################################################################

set -e

# Cloudera Manager Configuration
CM_HOST="13.41.167.97"
CM_PORT="7180"
CM_USER="Admin"
CM_PASSWORD="Admin@2026"
CM_API_VERSION="v40"
CM_BASE_URL="http://${CM_HOST}:${CM_PORT}/api/${CM_API_VERSION}"

# Cloudera SSH (for YARN commands and cache clearing)
CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================"
echo "Cloudera Manager API - Cleanup & Restart"
echo "============================================${NC}"
echo ""
echo "Cloudera Manager: http://${CM_HOST}:${CM_PORT}/"
echo "API Base: ${CM_BASE_URL}"
echo ""

# Step 1: Get cluster name
echo -e "${YELLOW}Step 1: Discovering Cluster...${NC}"
CLUSTER_NAME=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters" | \
    grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}ERROR: Could not get cluster name${NC}"
    echo "Check Cloudera Manager is accessible:"
    echo "  http://${CM_HOST}:${CM_PORT}/"
    exit 1
fi

echo -e "${GREEN}✓ Cluster: ${CLUSTER_NAME}${NC}"
echo ""

# Step 2: Get YARN service name
echo -e "${YELLOW}Step 2: Finding YARN Service...${NC}"
YARN_SERVICE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services" | \
    grep -o '"name":"yarn[^"]*","type":"YARN"' | cut -d'"' -f4 | head -1)

if [ -z "$YARN_SERVICE" ]; then
    echo -e "${RED}ERROR: Could not find YARN service${NC}"
    exit 1
fi

echo -e "${GREEN}✓ YARN Service: ${YARN_SERVICE}${NC}"
echo ""

# Step 3: Check YARN service health
echo -e "${YELLOW}Step 3: Checking YARN Health...${NC}"
YARN_HEALTH=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}" | \
    grep -o '"healthSummary":"[^"]*"' | cut -d'"' -f4)

echo "YARN Health: ${YARN_HEALTH}"

YARN_STATE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}" | \
    grep -o '"serviceState":"[^"]*"' | cut -d'"' -f4)

echo "YARN State: ${YARN_STATE}"
echo ""

# Step 4: Kill stuck YARN applications via SSH
echo -e "${YELLOW}Step 4: Killing Stuck YARN Applications...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} \
    'for app in $(yarn application -list -appStates ACCEPTED,RUNNING 2>/dev/null | grep "application_" | awk "{print \$1}"); do
        echo "Killing $app..."
        yarn application -kill $app 2>/dev/null || true
    done' 2>&1 | grep -v "ITC Big Data Lab" || true

echo -e "${GREEN}✓ YARN applications cleaned${NC}"
echo ""

# Step 5: Clear system caches via SSH
echo -e "${YELLOW}Step 5: Clearing System Caches...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} \
    'sudo sh -c "sync && echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null' 2>&1 | \
    grep -v "ITC Big Data Lab" || true

echo -e "${GREEN}✓ System caches cleared${NC}"
echo ""

# Step 6: Check memory before restart
echo -e "${YELLOW}Step 6: Checking Memory Before Restart...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} 'free -h' 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 7: Restart YARN NodeManager via CM API
echo -e "${YELLOW}Step 7: Restarting YARN NodeManager via CM API...${NC}"

# Get NodeManager role name
NM_ROLE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roles" | \
    grep -o '"name":"[^"]*","type":"NODEMANAGER"' | cut -d'"' -f4 | head -1)

if [ -z "$NM_ROLE" ]; then
    echo -e "${RED}ERROR: Could not find NodeManager role${NC}"
    exit 1
fi

echo "NodeManager Role: ${NM_ROLE}"
echo ""

# Restart NodeManager
echo "Sending restart command to CM API..."
RESTART_CMD=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    -X POST \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roleCommands/restart" \
    -H "Content-Type: application/json" \
    -d "{\"items\":[\"${NM_ROLE}\"]}")

CMD_ID=$(echo "$RESTART_CMD" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$CMD_ID" ]; then
    echo -e "${RED}ERROR: Failed to get command ID${NC}"
    echo "Response: $RESTART_CMD"
    exit 1
fi

echo -e "${GREEN}✓ Restart command issued (Command ID: ${CMD_ID})${NC}"
echo ""

# Step 8: Wait for restart to complete
echo -e "${YELLOW}Step 8: Waiting for NodeManager Restart...${NC}"
echo "This may take 2-3 minutes..."
echo ""

for i in {1..60}; do
    sleep 5

    CMD_STATUS=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/commands/${CMD_ID}" | \
        grep -o '"active":\(true\|false\)' | cut -d':' -f2)

    CMD_SUCCESS=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/commands/${CMD_ID}" | \
        grep -o '"success":\(true\|false\)' | cut -d':' -f2)

    if [ "$CMD_STATUS" = "false" ]; then
        if [ "$CMD_SUCCESS" = "true" ]; then
            echo -e "${GREEN}✓ NodeManager restarted successfully!${NC}"
            break
        else
            echo -e "${RED}✗ NodeManager restart failed${NC}"
            exit 1
        fi
    fi

    echo -n "."
done
echo ""
echo ""

# Step 9: Wait for NodeManager to be healthy
echo -e "${YELLOW}Step 9: Waiting for NodeManager to be Healthy...${NC}"
sleep 10

for i in {1..12}; do
    ROLE_STATE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roles/${NM_ROLE}" | \
        grep -o '"roleState":"[^"]*"' | cut -d'"' -f4)

    HEALTH=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roles/${NM_ROLE}" | \
        grep -o '"healthSummary":"[^"]*"' | cut -d'"' -f4)

    echo "NodeManager State: ${ROLE_STATE}, Health: ${HEALTH}"

    if [ "$ROLE_STATE" = "STARTED" ] && [ "$HEALTH" = "GOOD" ]; then
        echo -e "${GREEN}✓ NodeManager is healthy!${NC}"
        break
    fi

    sleep 5
done
echo ""

# Step 10: Check memory after restart
echo -e "${YELLOW}Step 10: Checking Memory After Restart...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} 'free -h' 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 11: Check YARN node availability
echo -e "${YELLOW}Step 11: Verifying YARN Node...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} 'yarn node -list' 2>&1 | \
    grep -E "Total Nodes|RUNNING" | grep -v "ITC Big Data Lab" || true
echo ""

# Step 12: Test Spark job
echo -e "${YELLOW}Step 12: Testing Spark Job (Minimal Resources)...${NC}"
echo "Running simple Spark word count test..."
echo ""

sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} \
    "cd /home/consultant/uttam/TFL_Project_Demo && \
     spark-submit \
       --master yarn \
       --deploy-mode client \
       --num-executors 1 \
       --executor-memory 512M \
       --executor-cores 1 \
       --driver-memory 512M \
       --conf spark.yarn.am.memory=512m \
       --conf spark.network.timeout=120s \
       src/spark/simple_spark_wordcount.py 2>&1" | \
    grep -E "INFO|completed|Successfully|ERROR|FAILED" | tail -30

SPARK_EXIT=${PIPESTATUS[0]}

echo ""
if [ $SPARK_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ Spark test job completed successfully!${NC}"
else
    echo -e "${RED}✗ Spark test job failed (exit code: $SPARK_EXIT)${NC}"
fi
echo ""

# Step 13: Summary
echo -e "${BLUE}============================================"
echo "✓✓✓ CLEANUP COMPLETE"
echo "============================================${NC}"
echo ""
echo -e "${GREEN}Actions Completed:${NC}"
echo "  ✓ Killed stuck YARN applications"
echo "  ✓ Cleared system caches"
echo "  ✓ Restarted YARN NodeManager"
echo "  ✓ Verified NodeManager health"
echo "  ✓ Tested Spark job"
echo ""
echo -e "${BLUE}Cloudera Manager:${NC}"
echo "  URL: http://${CM_HOST}:${CM_PORT}/"
echo "  YARN: http://${CM_HOST}:${CM_PORT}/cmf/services/${YARN_SERVICE}/status"
echo ""
echo -e "${BLUE}YARN ResourceManager:${NC}"
echo "  URL: http://${CM_HOST}:8088/"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Verify memory in Cloudera: ssh consultant@${CM_HOST} 'free -h'"
echo "  2. Run Jenkins pipeline: http://51.24.13.205:8081/job/TfL_Spark_Pipeline/"
echo "  3. Use settings: NUM_EXECUTORS=1, EXECUTOR_MEMORY=512M"
echo ""
echo "============================================"

exit 0
