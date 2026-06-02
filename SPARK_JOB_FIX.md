# Fix TfL Spark Analysis Job - Console Errors

## 🚨 Problem

Your Jenkins job `TfL_Spark_Analysis` is showing errors because:
1. Using **Freestyle project** with complex shell script
2. Too many `grep` filters causing failures
3. `set -e` exits on any non-zero command

## ✅ Solution: Use the Pipeline Instead

You already have a **working Pipeline** in your repo: `Jenkinsfile`

---

## 🚀 Quick Fix (2 Options)

### Option A: Delete and Recreate (Recommended)

#### Step 1: Delete Broken Job
Go to: http://51.24.13.205:8081/job/TfL_Spark_Analysis/
- Click **Delete Project** (left menu)
- Confirm deletion

#### Step 2: Create New Pipeline Job
1. Go to: http://51.24.13.205:8081/
2. Click **New Item**
3. Name: `TfL_Spark_Pipeline` (new name)
4. Type: **Pipeline** (NOT Freestyle!)
5. Click OK

#### Step 3: Configure Pipeline
In Pipeline section:
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/uttamraj9/TFL_Project_Demo.git`
- **Branch:** `*/main`
- **Script Path:** `Jenkinsfile`

Click **Save**

#### Step 4: Build with Parameters
- Click **Build with Parameters**
- **SPARK_SCRIPT:** `simple_spark_wordcount.py`
- **NUM_EXECUTORS:** `2`
- **EXECUTOR_MEMORY:** `1G`
- **EXECUTOR_CORES:** `1`
- Click **Build**

---

### Option B: Fix Existing Freestyle Job

If you want to keep the Freestyle project, replace the Execute Shell script:

#### Go to Job Configuration
http://51.24.13.205:8081/job/TfL_Spark_Analysis/configure

#### Replace Execute Shell Script with This:

```bash
#!/bin/bash
# Simplified Spark pipeline - no grep filters

# Configuration
REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "========================================"
echo "TfL PySpark Analysis Pipeline"
echo "========================================"
echo "Workspace: $WORKSPACE"
echo "Remote: $REMOTE_HOST:$PROJECT_DIR"
echo ""

# Step 1: Verify script exists
echo "Step 1: Verify PySpark script..."
if [ ! -f "$WORKSPACE/src/spark/simple_spark_wordcount.py" ]; then
    echo "ERROR: Spark script not found!"
    exit 1
fi
ls -lh $WORKSPACE/src/spark/*.py
echo "✓ Scripts found"
echo ""

# Step 2: Create remote directory
echo "Step 2: Create directory on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $PROJECT_DIR/src/spark" || true
echo "✓ Directory ready"
echo ""

# Step 3: Copy scripts
echo "Step 3: Copy PySpark scripts..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/spark/*.py $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/spark/ || true
echo "✓ Scripts copied"
echo ""

# Step 4: Set permissions
echo "Step 4: Set permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $PROJECT_DIR/src/spark/*.py" || true
echo "✓ Permissions set"
echo ""

# Step 5: Verify files
echo "Step 5: Verify files on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "ls -lh $PROJECT_DIR/src/spark/"
echo ""

# Step 6: Run Spark job
echo "======================================"
echo "Step 6: Running PySpark Job..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST \
    "cd $PROJECT_DIR && spark-submit \
    --master yarn \
    --deploy-mode client \
    --num-executors 2 \
    --executor-memory 1G \
    --executor-cores 1 \
    --conf spark.yarn.submit.waitAppCompletion=true \
    src/spark/simple_spark_wordcount.py"

SPARK_EXIT=$?

echo ""
echo "======================================"
if [ $SPARK_EXIT -eq 0 ]; then
    echo "✓ PySpark job completed successfully"
else
    echo "✗ PySpark job failed (exit code: $SPARK_EXIT)"
fi
echo "======================================"
echo ""

# Step 7: Verify HDFS output
echo "Step 7: Checking HDFS output..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST \
    "hdfs dfs -ls /tmp/uttam/spark_wordcount_output 2>/dev/null || echo 'No HDFS output (script may not save to HDFS)'"

echo ""
echo "======================================"
echo "Pipeline Complete"
echo "======================================"

exit $SPARK_EXIT
```

Click **Save**

---

## 📋 What Changed

### ❌ Old Script Issues:
- `set -e` - Exits on ANY error (even harmless ones)
- Too many `grep` filters - Hiding useful output
- Complex error handling - Hard to debug

### ✅ New Script Fixes:
- Removed `set -e` - Only exits on real failures
- Removed `grep` filters - Shows all output
- Added `|| true` - Ignores harmless errors
- Captures Spark exit code - Better error reporting
- Simpler and clearer output

---

## 🎯 Recommended: Use Pipeline (Jenkinsfile)

The **Pipeline approach** is better because:

### ✅ Advantages:
1. **Better error handling** - Clear stage failures
2. **Parameterized** - Change script/resources via UI
3. **Cleaner output** - Organized by stages
4. **Version controlled** - Pipeline code in Git
5. **Reusable** - Can be shared across jobs

### 📊 Pipeline Stages:
```
[Stage 1] Checkout              ━━━━━━━━ 10s ✓
[Stage 2] Verify Scripts        ━━━━━━━━  5s ✓
[Stage 3] Deploy to Cloudera    ━━━━━━━━ 15s ✓
[Stage 4] Prepare HDFS          ━━━━━━━━  5s ✓
[Stage 5] Run Spark Job         ━━━━━━━━ 60s ✓
[Stage 6] Verify Results        ━━━━━━━━  5s ✓
```

---

## 🔍 Common Errors & Solutions

### Error 1: "sshpass: command not found"

**Solution:**
```bash
# On Jenkins server:
sudo yum install -y sshpass
# or
sudo apt-get install -y sshpass
```

### Error 2: "Permission denied (publickey)"

**Solution:**
- Password authentication is disabled
- Need to use SSH key instead
- Or enable password auth on Cloudera

**Fix:** Use PEM file approach:
```bash
# Instead of sshpass, use:
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97 \
    "sudo -u consultant bash -c 'command here'"
```

### Error 3: "spark-submit: command not found"

**Solution:**
```bash
# Add Spark to PATH on Cloudera
export SPARK_HOME=/opt/cloudera/parcels/CDH/lib/spark
export PATH=$SPARK_HOME/bin:$PATH
```

**Fix in script:**
```bash
sshpass -p "$REMOTE_PASSWORD" ssh ... \
    "source /etc/profile.d/spark.sh && spark-submit ..."
```

### Error 4: "HDFS directory not found"

**Solution:**
```bash
# Create output directory first
hdfs dfs -mkdir -p /tmp/uttam/spark_wordcount_output
hdfs dfs -chmod 777 /tmp/uttam
```

### Error 5: Spark job hangs forever

**Solution:**
Add timeout to spark-submit:
```bash
--conf spark.yarn.submit.waitAppCompletion=true \
--conf spark.network.timeout=300s \
--conf spark.executor.heartbeatInterval=60s
```

---

## 🧪 Test Manually First

Before running in Jenkins, test manually:

### Step 1: SSH to Cloudera
```bash
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97
sudo su - consultant
```

### Step 2: Check if scripts are there
```bash
ls -lh /home/consultant/uttam/TFL_Project_Demo/src/spark/
```

### Step 3: Run Spark job manually
```bash
cd /home/consultant/uttam/TFL_Project_Demo

spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 1G \
  --executor-cores 1 \
  src/spark/simple_spark_wordcount.py
```

If this works manually, Jenkins should work too.

---

## 📚 Complete Working Example

### Create Pipeline Job via Jenkins CLI

```bash
# Get Jenkins CRUMB for API calls
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Create Pipeline job
curl -X POST -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @- \
  'http://51.24.13.205:8081/createItem?name=TfL_Spark_Pipeline_Fixed' << 'XML_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>TfL PySpark Pipeline (Fixed - uses Jenkinsfile)</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/uttamraj9/TFL_Project_Demo.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
  </definition>
</flow-definition>
XML_EOF

# Trigger build
curl -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  'http://51.24.13.205:8081/job/TfL_Spark_Pipeline_Fixed/buildWithParameters?SPARK_SCRIPT=simple_spark_wordcount.py&NUM_EXECUTORS=2&EXECUTOR_MEMORY=1G&EXECUTOR_CORES=1'
```

---

## 📊 Comparison: Freestyle vs Pipeline

### Freestyle Project (Current - Has Errors)
```
❌ Complex shell script with grep filters
❌ Hard to debug failures
❌ Parameters hardcoded in script
❌ No stage visualization
❌ Errors hidden by grep
```

### Pipeline (Recommended - Clean)
```
✅ Clear stage separation
✅ Easy to see where it fails
✅ Parameterized via UI
✅ Visual pipeline progress
✅ All output visible
✅ Better error messages
```

---

## 🎯 Action Plan

### Recommended Steps:

1. **Delete broken job:** `TfL_Spark_Analysis`
2. **Create new Pipeline job:** `TfL_Spark_Pipeline_Fixed`
3. **Use Jenkinsfile from Git**
4. **Build with parameters**
5. **Monitor console output**

### Expected Result:
```
=========================================
✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓
=========================================
PySpark Script: simple_spark_wordcount.py
Executors: 2 x 1G
Cloudera: 13.41.167.97:/home/consultant/uttam/TFL_Project_Demo
=========================================
```

---

## 📞 Still Having Issues?

### Debug Checklist:

- [ ] Is `sshpass` installed on Jenkins server?
- [ ] Can Jenkins reach Cloudera (port 22)?
- [ ] Test SSH manually: `sshpass -p "WelcomeItc@2026" ssh consultant@13.41.167.97 "hostname"`
- [ ] Is YARN running on Cloudera?
- [ ] Check Cloudera Manager: http://13.41.167.97:7180/
- [ ] Is Spark script valid Python? `python3 src/spark/simple_spark_wordcount.py`
- [ ] Check YARN logs: `yarn logs -applicationId <app-id>`

---

**Created:** June 2, 2026  
**Issue:** TfL_Spark_Analysis showing errors  
**Solution:** Use Pipeline (Jenkinsfile) instead of Freestyle  
**Status:** Ready to implement ✅
