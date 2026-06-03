#!/bin/bash
###############################################################################
# Cloudera Memory Cleanup Script
# Frees up memory and prepares cluster for Spark YARN jobs
###############################################################################

echo "============================================"
echo "Cloudera Memory Cleanup & Optimization"
echo "============================================"
echo ""

# Step 1: Check current memory
echo "Step 1: Current Memory Status"
echo "------------------------------"
free -h
echo ""

MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
echo "Available memory: ${MEM_AVAILABLE} MB"

if [ "$MEM_AVAILABLE" -lt 2000 ]; then
    echo "⚠ WARNING: Low memory detected (< 2GB available)"
    echo "Proceeding with cleanup..."
else
    echo "✓ Memory looks good"
fi
echo ""

# Step 2: Check what's consuming memory
echo "Step 2: Top Memory Consumers"
echo "------------------------------"
ps aux --sort=-%mem | head -15
echo ""

# Step 3: Kill stuck YARN applications
echo "Step 3: Killing Stuck YARN Applications"
echo "----------------------------------------"
yarn application -list -appStates ACCEPTED,RUNNING

echo ""
echo "Killing all ACCEPTED/RUNNING applications..."
for APP in $(yarn application -list -appStates ACCEPTED,RUNNING 2>/dev/null | grep 'application_' | awk '{print $1}'); do
    echo "  Killing $APP..."
    yarn application -kill $APP 2>/dev/null || true
done
echo "✓ YARN applications cleaned"
echo ""

# Step 4: Clear system caches (requires root/sudo)
echo "Step 4: Clearing System Caches"
echo "-------------------------------"
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    echo "Dropping caches (requires root)..."
    sync
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    echo "✓ System caches cleared"
else
    echo "⚠ Skipping cache clear (requires sudo)"
fi
echo ""

# Step 5: Check for zombie processes
echo "Step 5: Checking for Zombie Processes"
echo "--------------------------------------"
ZOMBIES=$(ps aux | grep -w Z | grep -v grep | wc -l)
echo "Zombie processes: $ZOMBIES"
if [ "$ZOMBIES" -gt 0 ]; then
    echo "⚠ Found zombie processes (may need reboot)"
fi
echo ""

# Step 6: Check Java processes
echo "Step 6: Java Processes (Hadoop/Spark)"
echo "--------------------------------------"
ps aux | grep -E 'java|hadoop|spark' | grep -v grep | awk '{print $2, $3, $4, $11}' | column -t
echo ""

# Step 7: YARN NodeManager status
echo "Step 7: YARN NodeManager Status"
echo "--------------------------------"
yarn node -list -all
echo ""

# Step 8: Final memory check
echo "Step 8: Memory After Cleanup"
echo "----------------------------"
free -h
echo ""

MEM_AVAILABLE_AFTER=$(free -m | awk 'NR==2 {print $7}')
echo "Available memory: ${MEM_AVAILABLE_AFTER} MB"
FREED=$((MEM_AVAILABLE_AFTER - MEM_AVAILABLE))
echo "Memory freed: ${FREED} MB"
echo ""

# Step 9: Recommendations
echo "============================================"
echo "✓ Cleanup Complete"
echo "============================================"
echo ""

if [ "$MEM_AVAILABLE_AFTER" -lt 2000 ]; then
    echo "⚠ Still low memory. Recommendations:"
    echo ""
    echo "Option 1: Restart Cloudera Services (Frees most memory)"
    echo "---------------------------------------------------------"
    echo "Via Cloudera Manager:"
    echo "  1. Go to: http://13.41.167.97:7180/"
    echo "  2. User: Admin | Pass: Admin@2026"
    echo "  3. Select: Cluster 1"
    echo "  4. Click: Actions > Restart"
    echo "  5. Wait 5-10 minutes"
    echo ""
    echo "Option 2: Restart YARN Only (Faster)"
    echo "-------------------------------------"
    echo "Via Cloudera Manager:"
    echo "  1. Go to: YARN service"
    echo "  2. Click: Actions > Restart"
    echo "  3. Wait 2-3 minutes"
    echo ""
    echo "Option 3: Reboot Server (Nuclear option)"
    echo "-----------------------------------------"
    echo "  sudo reboot"
    echo ""
else
    echo "✓ Memory looks good (${MEM_AVAILABLE_AFTER} MB available)"
    echo ""
    echo "Ready to run Spark jobs!"
    echo ""
    echo "Recommended Spark settings for your cluster:"
    echo "  --num-executors 2"
    echo "  --executor-memory 2G"
    echo "  --executor-cores 2"
    echo "  --driver-memory 1G"
fi

echo "============================================"
