#!/bin/bash
###############################################################################
# Fix YARN Stuck Applications - Kill stuck Spark jobs and free resources
###############################################################################

set -e

CLOUDERA_HOST="13.41.167.97"
CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"

echo "=========================================="
echo "YARN Stuck Application Fix"
echo "=========================================="
echo "Cloudera: $CLOUDERA_HOST"
echo ""

# Step 1: Check YARN applications
echo "Step 1: Checking YARN applications..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "yarn application -list -appStates ACCEPTED,RUNNING" 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 2: Kill stuck application
STUCK_APP="application_1778572939149_0244"
echo "Step 2: Killing stuck application: $STUCK_APP"
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "yarn application -kill $STUCK_APP" 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 3: Check NodeManager resources
echo "Step 3: Checking YARN NodeManager resources..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "yarn node -list -all" 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 4: Check system memory
echo "Step 4: Checking system memory..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "free -h" 2>&1 | grep -v "ITC Big Data Lab" || true
echo ""

# Step 5: Restart YARN NodeManager (if needed)
echo "Step 5: Do you want to restart YARN NodeManager? (y/n)"
read -r RESTART

if [ "$RESTART" = "y" ]; then
    echo "Restarting YARN NodeManager..."
    echo "⚠ This requires Cloudera Manager credentials"
    echo "Access: http://13.41.167.97:7180/"
    echo "User: Admin | Pass: Admin@2026"
    echo ""
    echo "Manual steps:"
    echo "1. Login to Cloudera Manager"
    echo "2. Go to: Clusters > Cluster 1 > YARN"
    echo "3. Click: Actions > Restart"
    echo "4. Wait for restart (2-3 minutes)"
else
    echo "Skipping NodeManager restart"
fi

echo ""
echo "=========================================="
echo "✓ Cleanup Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait 30 seconds for YARN to stabilize"
echo "2. Rebuild Spark pipeline with lower resources:"
echo "   NUM_EXECUTORS: 1 (instead of 2)"
echo "   EXECUTOR_MEMORY: 512M (instead of 1G)"
echo "3. Monitor YARN UI: http://13.41.167.97:8088/"
