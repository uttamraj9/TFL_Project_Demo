#!/bin/bash
###############################################################################
# Restart Cloudera Cluster - Full Recovery Script
# Use when Cloudera services are down
###############################################################################

set -e

CM_HOST="13.41.167.97"
CM_PORT="7180"
CM_USER="Admin"
CM_PASSWORD="Admin@2026"
CM_API_VERSION="v40"
CM_BASE_URL="http://${CM_HOST}:${CM_PORT}/api/${CM_API_VERSION}"

CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║     CLOUDERA CLUSTER RECOVERY                     ║${NC}"
echo -e "${RED}║     Cluster appears to be down - restarting...    ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if server is reachable
echo -e "${YELLOW}Step 1: Checking server connectivity...${NC}"
if ping -c 3 ${CM_HOST} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is reachable${NC}"
else
    echo -e "${RED}✗ Server is not reachable${NC}"
    echo "Possible issues:"
    echo "  1. Server is powered off"
    echo "  2. Network issue"
    echo "  3. EC2 instance stopped"
    echo ""
    echo "Actions:"
    echo "  • Check AWS EC2 console"
    echo "  • Restart EC2 instance if stopped"
    echo "  • Check network/VPN connection"
    exit 1
fi
echo ""

# Step 2: Check if SSH works
echo -e "${YELLOW}Step 2: Testing SSH access...${NC}"
if sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} "hostname" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH access working${NC}"
else
    echo -e "${RED}✗ SSH access failed${NC}"
    echo "Server is reachable but SSH not responding"
    echo "Actions:"
    echo "  • Wait 2-3 minutes for SSH to start"
    echo "  • Check if system is booting"
    echo "  • Try: ssh -i ~/Downloads/Training/test_key.pem ec2-user@${CM_HOST}"
    exit 1
fi
echo ""

# Step 3: Check Cloudera Manager web UI
echo -e "${YELLOW}Step 3: Checking Cloudera Manager status...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${CM_USER}:${CM_PASSWORD}" \
    --connect-timeout 10 \
    "${CM_BASE_URL}/tools/echo")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Cloudera Manager is responding${NC}"
else
    echo -e "${YELLOW}⚠ Cloudera Manager not responding (HTTP $HTTP_CODE)${NC}"
    echo "Starting Cloudera Manager service..."

    sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null ${CLOUDERA_USER}@${CM_HOST} \
        "sudo systemctl status cloudera-scm-server" 2>&1 | grep -q "running" || \
        sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null ${CLOUDERA_USER}@${CM_HOST} \
            "sudo systemctl start cloudera-scm-server" || true

    echo "Waiting for Cloudera Manager to start (this may take 2-3 minutes)..."
    sleep 60

    # Check again
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "${CM_USER}:${CM_PASSWORD}" \
        --connect-timeout 10 \
        "${CM_BASE_URL}/tools/echo")

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Cloudera Manager started${NC}"
    else
        echo -e "${RED}✗ Cloudera Manager failed to start${NC}"
        echo "Manual intervention needed:"
        echo "  1. SSH to server: ssh -i ~/Downloads/Training/test_key.pem ec2-user@${CM_HOST}"
        echo "  2. Check CM logs: sudo tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log"
        echo "  3. Start manually: sudo systemctl start cloudera-scm-server"
        exit 1
    fi
fi
echo ""

# Step 4: Get cluster name
echo -e "${YELLOW}Step 4: Discovering cluster...${NC}"
CLUSTER_NAME=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters" 2>/dev/null | \
    grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}✗ Could not find cluster${NC}"
    echo "Cloudera Manager may still be starting. Wait 2-3 minutes and try again."
    exit 1
fi
echo -e "${GREEN}✓ Cluster: ${CLUSTER_NAME}${NC}"
echo ""

# Step 5: Check cluster status
echo -e "${YELLOW}Step 5: Checking cluster status...${NC}"
CLUSTER_STATE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}" | \
    grep -o '"clusterState":"[^"]*"' | cut -d'"' -f4)

echo "Cluster State: ${CLUSTER_STATE}"

if [ "$CLUSTER_STATE" = "STARTED" ] || [ "$CLUSTER_STATE" = "STARTING" ]; then
    echo -e "${GREEN}✓ Cluster is already started or starting${NC}"
else
    echo -e "${YELLOW}Cluster is ${CLUSTER_STATE}, starting it now...${NC}"

    # Start the cluster
    START_CMD=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        -X POST \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/commands/start")

    CMD_ID=$(echo "$START_CMD" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

    if [ -z "$CMD_ID" ]; then
        echo -e "${RED}✗ Failed to start cluster${NC}"
        exit 1
    fi

    echo "Cluster start command issued (ID: ${CMD_ID})"
    echo "This may take 5-10 minutes..."
fi
echo ""

# Step 6: Wait for services to start
echo -e "${YELLOW}Step 6: Waiting for services to start...${NC}"
echo "Key services: HDFS, YARN, Hive, HBase"
echo ""

for i in {1..60}; do
    sleep 10

    # Get all services
    SERVICES=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services")

    # Check HDFS
    HDFS_STATE=$(echo "$SERVICES" | grep -o '"name":"hdfs","type":"HDFS","serviceState":"[^"]*"' | cut -d'"' -f12 || echo "UNKNOWN")

    # Check YARN
    YARN_STATE=$(echo "$SERVICES" | grep -o '"name":"yarn[^"]*","type":"YARN","serviceState":"[^"]*"' | grep -o 'serviceState":"[^"]*"' | cut -d'"' -f3 || echo "UNKNOWN")

    echo "[$i] HDFS: ${HDFS_STATE}, YARN: ${YARN_STATE}"

    if [ "$HDFS_STATE" = "STARTED" ] && [ "$YARN_STATE" = "STARTED" ]; then
        echo ""
        echo -e "${GREEN}✓ Core services are STARTED${NC}"
        break
    fi
done
echo ""

# Step 7: Verify YARN NodeManager
echo -e "${YELLOW}Step 7: Verifying YARN NodeManager...${NC}"
sleep 10

YARN_NODES=$(sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null ${CLOUDERA_USER}@${CM_HOST} \
    "yarn node -list 2>&1 | grep -E 'Total Nodes|RUNNING'" || echo "Not ready")

echo "$YARN_NODES"

if echo "$YARN_NODES" | grep -q "RUNNING"; then
    echo -e "${GREEN}✓ YARN NodeManager is RUNNING${NC}"
else
    echo -e "${YELLOW}⚠ YARN may still be starting, give it 2-3 more minutes${NC}"
fi
echo ""

# Step 8: Check memory
echo -e "${YELLOW}Step 8: Checking system memory...${NC}"
sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null ${CLOUDERA_USER}@${CM_HOST} \
    "free -h | grep 'Mem:'"
echo ""

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CLOUDERA CLUSTER RECOVERY COMPLETE               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Services Status:${NC}"
echo "  • Server: Reachable"
echo "  • SSH: Working"
echo "  • Cloudera Manager: Running"
echo "  • Cluster: ${CLUSTER_STATE}"
echo "  • HDFS: ${HDFS_STATE}"
echo "  • YARN: ${YARN_STATE}"
echo ""

echo -e "${BLUE}Access Points:${NC}"
echo "  • Cloudera Manager: http://${CM_HOST}:${CM_PORT}/"
echo "    User: ${CM_USER} | Pass: ${CM_PASSWORD}"
echo ""
echo "  • YARN RM: http://${CM_HOST}:8088/"
echo ""
echo "  • SSH: ssh -i ~/Downloads/Training/test_key.pem ec2-user@${CM_HOST}"
echo ""

if [ "$YARN_STATE" = "STARTED" ]; then
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Wait 2-3 minutes for all services to stabilize"
    echo "  2. Run memory cleanup: ./cloudera_api_cleanup.sh"
    echo "  3. Trigger Jenkins pipeline: http://51.24.13.205:8081/job/TfL_Spark_Pipeline/"
    echo ""
    echo -e "${GREEN}✓✓✓ CLUSTER IS READY ✓✓✓${NC}"
else
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Wait 5 more minutes for services to fully start"
    echo "  2. Check Cloudera Manager UI for any errors"
    echo "  3. Run this script again if needed"
    echo ""
    echo -e "${YELLOW}⚠ CLUSTER IS STARTING (be patient)${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════"

exit 0
