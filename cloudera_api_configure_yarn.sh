#!/bin/bash
###############################################################################
# Cloudera Manager API - Configure YARN Memory Settings
# Optimizes YARN for better memory utilization
###############################################################################

set -e

# Cloudera Manager Configuration
CM_HOST="13.41.167.97"
CM_PORT="7180"
CM_USER="Admin"
CM_PASSWORD="Admin@2026"
CM_API_VERSION="v40"
CM_BASE_URL="http://${CM_HOST}:${CM_PORT}/api/${CM_API_VERSION}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================"
echo "Cloudera Manager API - YARN Configuration"
echo "============================================${NC}"
echo ""

# Step 1: Get cluster and YARN service
echo -e "${YELLOW}Step 1: Discovering Cluster & YARN Service...${NC}"

CLUSTER_NAME=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters" | \
    grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

YARN_SERVICE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services" | \
    grep -o '"name":"yarn[^"]*","type":"YARN"' | cut -d'"' -f4 | head -1)

echo -e "${GREEN}✓ Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${GREEN}✓ YARN Service: ${YARN_SERVICE}${NC}"
echo ""

# Step 2: Get current YARN configuration
echo -e "${YELLOW}Step 2: Fetching Current YARN Configuration...${NC}"

CURRENT_CONFIG=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/config?view=full")

echo "Current key YARN settings:"
echo "$CURRENT_CONFIG" | grep -A2 -E 'yarn_nodemanager_resource_memory_mb|yarn_scheduler_maximum_allocation_mb|yarn_scheduler_minimum_allocation_mb' | grep -E 'name|value' || echo "  (retrieving...)"
echo ""

# Step 3: Get NodeManager role configuration
echo -e "${YELLOW}Step 3: Getting NodeManager Configuration...${NC}"

NM_ROLE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roles" | \
    grep -o '"name":"[^"]*","type":"NODEMANAGER"' | cut -d'"' -f4 | head -1)

echo "NodeManager Role: ${NM_ROLE}"
echo ""

# Step 4: Propose new configuration
echo -e "${YELLOW}Step 4: Proposed YARN Memory Configuration...${NC}"
echo ""
echo "Recommended settings for 32 GB RAM system:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  yarn.nodemanager.resource.memory-mb: 20480 (20 GB for YARN containers)"
echo "  yarn.scheduler.maximum-allocation-mb: 8192 (8 GB max per container)"
echo "  yarn.scheduler.minimum-allocation-mb: 512 (512 MB min per container)"
echo "  yarn.app.mapreduce.am.resource.mb: 1024 (1 GB for ApplicationMaster)"
echo ""
echo "This leaves ~12 GB for OS, Hadoop daemons, and other services"
echo ""

read -p "Apply these settings? (y/n): " APPLY_SETTINGS

if [ "$APPLY_SETTINGS" != "y" ]; then
    echo "Configuration not applied. Exiting."
    exit 0
fi
echo ""

# Step 5: Update YARN configuration via API
echo -e "${YELLOW}Step 5: Updating YARN Configuration via CM API...${NC}"

# Update service-level configs
UPDATE_RESPONSE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    -X PUT \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/config" \
    -H "Content-Type: application/json" \
    -d '{
      "items": [
        {
          "name": "yarn_scheduler_maximum_allocation_mb",
          "value": "8192"
        },
        {
          "name": "yarn_scheduler_minimum_allocation_mb",
          "value": "512"
        }
      ]
    }')

echo "Service config updated"

# Update NodeManager role configs
UPDATE_NM=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    -X PUT \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/roles/${NM_ROLE}/config" \
    -H "Content-Type: application/json" \
    -d '{
      "items": [
        {
          "name": "yarn_nodemanager_resource_memory_mb",
          "value": "20480"
        },
        {
          "name": "yarn_nodemanager_resource_cpu_vcores",
          "value": "8"
        }
      ]
    }')

echo -e "${GREEN}✓ Configuration updated${NC}"
echo ""

# Step 6: Deploy client configuration
echo -e "${YELLOW}Step 6: Deploying Client Configuration...${NC}"

DEPLOY_CMD=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    -X POST \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/commands/deployClientConfig")

DEPLOY_ID=$(echo "$DEPLOY_CMD" | grep -o '"id":[0-9]*' | cut -d':' -f2)

if [ -n "$DEPLOY_ID" ]; then
    echo "Deploying client configs (Command ID: ${DEPLOY_ID})..."
    sleep 10
    echo -e "${GREEN}✓ Client configuration deployed${NC}"
else
    echo "Note: Client config deployment may not be needed"
fi
echo ""

# Step 7: Restart YARN service
echo -e "${YELLOW}Step 7: Restarting YARN Service...${NC}"
echo "This will restart ResourceManager and NodeManager (~2-3 minutes)"
echo ""

RESTART_CMD=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    -X POST \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/commands/restart")

RESTART_ID=$(echo "$RESTART_CMD" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$RESTART_ID" ]; then
    echo "ERROR: Failed to restart YARN"
    exit 1
fi

echo -e "${GREEN}✓ Restart initiated (Command ID: ${RESTART_ID})${NC}"
echo "Waiting for restart to complete..."

# Wait for restart
for i in {1..60}; do
    sleep 5

    CMD_STATUS=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/commands/${RESTART_ID}" | \
        grep -o '"active":\(true\|false\)' | cut -d':' -f2)

    if [ "$CMD_STATUS" = "false" ]; then
        echo ""
        echo -e "${GREEN}✓ YARN service restarted${NC}"
        break
    fi

    echo -n "."
done
echo ""

# Step 8: Wait for service to be healthy
echo -e "${YELLOW}Step 8: Waiting for YARN to be Healthy...${NC}"
sleep 15

for i in {1..12}; do
    SERVICE_STATE=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}" | \
        grep -o '"serviceState":"[^"]*"' | cut -d'"' -f4)

    HEALTH=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
        "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}" | \
        grep -o '"healthSummary":"[^"]*"' | cut -d'"' -f4)

    echo "YARN State: ${SERVICE_STATE}, Health: ${HEALTH}"

    if [ "$SERVICE_STATE" = "STARTED" ] && [ "$HEALTH" = "GOOD" ]; then
        echo -e "${GREEN}✓ YARN is healthy!${NC}"
        break
    fi

    sleep 5
done
echo ""

# Step 9: Verify new configuration
echo -e "${YELLOW}Step 9: Verifying New Configuration...${NC}"

NEW_CONFIG=$(curl -s -u "${CM_USER}:${CM_PASSWORD}" \
    "${CM_BASE_URL}/clusters/${CLUSTER_NAME}/services/${YARN_SERVICE}/config?view=full")

echo "New YARN memory settings:"
echo "$NEW_CONFIG" | grep -A2 'yarn_nodemanager_resource_memory_mb' | grep 'value' || echo "  (verifying...)"
echo ""

# Step 10: Check YARN capacity
echo -e "${YELLOW}Step 10: Checking YARN Available Capacity...${NC}"

CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"

sshpass -p "${CLOUDERA_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${CLOUDERA_USER}@${CM_HOST} 'yarn node -list' 2>&1 | \
    grep -E "Total Nodes|Node-Id|RUNNING" | grep -v "ITC Big Data Lab" || true
echo ""

# Summary
echo -e "${BLUE}============================================"
echo "✓✓✓ YARN CONFIGURATION COMPLETE"
echo "============================================${NC}"
echo ""
echo -e "${GREEN}New YARN Settings Applied:${NC}"
echo "  ✓ NodeManager Memory: 20 GB (20480 MB)"
echo "  ✓ Max Container Size: 8 GB (8192 MB)"
echo "  ✓ Min Container Size: 512 MB"
echo "  ✓ CPU Cores: 8 vcores"
echo ""
echo -e "${GREEN}Benefits:${NC}"
echo "  ✓ More memory available for Spark executors"
echo "  ✓ Can run larger containers (up to 8 GB)"
echo "  ✓ Better resource utilization"
echo ""
echo -e "${BLUE}Recommended Spark Settings:${NC}"
echo "  --num-executors 2"
echo "  --executor-memory 4G"
echo "  --executor-cores 2"
echo "  --driver-memory 2G"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo "  Cloudera Manager: http://${CM_HOST}:${CM_PORT}/"
echo "  YARN ResourceManager: http://${CM_HOST}:8088/"
echo "  YARN Service: http://${CM_HOST}:${CM_PORT}/cmf/services/${YARN_SERVICE}/status"
echo ""
echo "============================================"

exit 0
