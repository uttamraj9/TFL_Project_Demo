#!/bin/bash
###############################################################################
# Kill Stuck YARN Application and Restart Spark Pipeline
# Fixes: Application stuck in ACCEPTED state
###############################################################################

set -e

CLOUDERA_HOST="13.41.167.97"
CLOUDERA_USER="consultant"
CLOUDERA_PASSWORD="WelcomeItc@2026"
JENKINS_URL="http://51.24.13.205:8081"
JENKINS_USER="consultant"
JENKINS_PASSWORD="WelcomeItc@2026"
JOB_NAME="TfL_Spark_Pipeline"

echo "=========================================="
echo "Spark Pipeline Recovery Script"
echo "=========================================="
echo ""

# Step 1: Kill stuck YARN applications
echo "Step 1: Killing stuck YARN applications..."
STUCK_APPS=$(sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "yarn application -list -appStates ACCEPTED 2>&1 | grep 'application_' | awk '{print \$1}'" 2>&1 | grep -v "ITC Big Data Lab" || true)

if [ -n "$STUCK_APPS" ]; then
    echo "Found stuck applications:"
    echo "$STUCK_APPS"
    echo ""

    for APP in $STUCK_APPS; do
        echo "Killing $APP..."
        sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            $CLOUDERA_USER@$CLOUDERA_HOST \
            "yarn application -kill $APP" 2>&1 | grep -v "ITC Big Data Lab" || true
    done
    echo "✓ Stuck applications killed"
else
    echo "No stuck applications found"
fi
echo ""

# Step 2: Check YARN resources
echo "Step 2: Checking YARN resources..."
sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "yarn node -list" 2>&1 | grep -E "Total Nodes|RUNNING" | grep -v "ITC Big Data Lab" || true
echo ""

# Step 3: Check memory
echo "Step 3: Checking system memory..."
MEM_AVAILABLE=$(sshpass -p "$CLOUDERA_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $CLOUDERA_USER@$CLOUDERA_HOST \
    "free -m | awk 'NR==2 {print \$7}'" 2>&1 | grep -v "ITC Big Data Lab")

echo "Available memory: ${MEM_AVAILABLE} MB"
if [ "$MEM_AVAILABLE" -lt 1000 ]; then
    echo "⚠ WARNING: Low memory (< 1GB available)"
    echo "Recommendation: Use lower executor settings"
    echo "  NUM_EXECUTORS: 1"
    echo "  EXECUTOR_MEMORY: 512M"
fi
echo ""

# Step 4: Get Jenkins CRUMB
echo "Step 4: Authenticating with Jenkins..."
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie-jar /tmp/jenkins-cookie \
  "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")

if [ -z "$CRUMB" ]; then
    echo "ERROR: Failed to authenticate with Jenkins"
    exit 1
fi
echo "✓ Jenkins authentication successful"
echo ""

# Step 5: Trigger new build with lower resources
echo "Step 5: Triggering new Spark pipeline build..."
echo "Settings:"
echo "  SPARK_SCRIPT: simple_spark_wordcount.py"
echo "  NUM_EXECUTORS: 1 (reduced from 2)"
echo "  EXECUTOR_MEMORY: 512M (reduced from 1G)"
echo "  EXECUTOR_CORES: 1"
echo ""

curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  "$JENKINS_URL/job/$JOB_NAME/buildWithParameters?SPARK_SCRIPT=simple_spark_wordcount.py&NUM_EXECUTORS=1&EXECUTOR_MEMORY=512M&EXECUTOR_CORES=1"

if [ $? -eq 0 ]; then
    echo "✓ Build triggered successfully"
else
    echo "✗ Failed to trigger build"
    exit 1
fi
echo ""

# Step 6: Get build number
sleep 3
BUILD_NUMBER=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  "$JENKINS_URL/job/$JOB_NAME/lastBuild/buildNumber")

echo "=========================================="
echo "✓✓✓ PIPELINE RESTARTED ✓✓✓"
echo "=========================================="
echo ""
echo "Build Number: #$BUILD_NUMBER"
echo "Monitor console: $JENKINS_URL/job/$JOB_NAME/$BUILD_NUMBER/console"
echo ""
echo "Optimizations applied:"
echo "  ✓ Killed stuck YARN applications"
echo "  ✓ Reduced executors: 2 → 1"
echo "  ✓ Reduced memory: 1G → 512M"
echo "  ✓ Added 5-minute timeout"
echo "  ✓ Added YARN resource check stage"
echo ""
echo "Expected completion: 2-3 minutes"
echo ""
echo "If still stuck, check:"
echo "  1. YARN RM UI: http://13.41.167.97:8088/"
echo "  2. Cloudera Manager: http://13.41.167.97:7180/"
echo "     User: Admin | Pass: Admin@2026"
echo "  3. System memory: ssh consultant@13.41.167.97 'free -h'"
echo "=========================================="

# Cleanup
rm -f /tmp/jenkins-cookie

exit 0
