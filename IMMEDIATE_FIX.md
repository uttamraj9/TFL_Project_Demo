# Immediate Fix for Stuck Spark Pipeline

## 🚨 Problem
Your Spark job is stuck in YARN **ACCEPTED** state - the application was submitted but can't get resources to run.

**Stuck Application:** `application_1778572939149_0244`

---

## ✅ Quick Fix (3 Steps - 2 Minutes)

### Step 1: Kill Stuck YARN Applications

SSH to Cloudera and kill the stuck applications:

```bash
# From your laptop:
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97

# Once connected:
sudo su - consultant

# Kill stuck applications:
yarn application -list -appStates ACCEPTED,RUNNING

# Kill each one (replace with actual app IDs):
yarn application -kill application_1778572939149_0244
yarn application -kill application_1778572939149_0245

# Verify they're gone:
yarn application -list -appStates ACCEPTED,RUNNING
# Should show: "Total number of applications: 0"
```

---

### Step 2: Check YARN Resources

```bash
# Still on Cloudera as consultant user:

# Check NodeManager:
yarn node -list
# Should show: Total Nodes: 1, RUNNING: 1

# Check memory:
free -h
# Need at least 1GB available

# If no nodes running or memory low:
# Go to Cloudera Manager: http://13.41.167.97:7180/
# User: Admin | Pass: Admin@2026
# Restart YARN NodeManager
```

---

### Step 3: Rebuild Pipeline with Lower Resources

Go to Jenkins: http://51.24.13.205:8081/job/TfL_Spark_Pipeline/

Click **"Build with Parameters"**

**Use these reduced settings:**
```
SPARK_SCRIPT:      simple_spark_wordcount.py
NUM_EXECUTORS:     1                          ◄── Changed from 2
EXECUTOR_MEMORY:   512M                       ◄── Changed from 1G
EXECUTOR_CORES:    1
```

Click **"Build"**

Monitor: http://51.24.13.205:8081/job/TfL_Spark_Pipeline/lastBuild/console

---

## 🔧 What Changed in Updated Jenkinsfile

I've already pushed fixes to GitHub. The new pipeline includes:

### ✅ New Features:
1. **5-minute timeout** - Won't hang forever
2. **YARN resource check** - Detects issues before running
3. **Reduced resources** - Less memory pressure
4. **Better logging** - Saves output to `/tmp/spark_output.log`
5. **Spark optimizations**:
   - `spark.yarn.queue=default`
   - `spark.yarn.am.memory=512m`
   - `spark.network.timeout=120s`
   - `spark.executor.heartbeatInterval=20s`

---

## 📊 Expected Output (New Build)

### Stage 4: Check YARN Resources (NEW!)
```
Checking YARN NodeManager status...
Total Nodes: 1
Node-Id             Node-State Node-Http-Address    RUNNING

Checking for stuck applications...
Total number of applications: 0  ◄── Good!

Checking system memory...
Mem:           15Gi        8.0Gi       3.5Gi
available      4.8Gi                            ◄── Good!
```

### Stage 6: Execute PySpark Job (WITH TIMEOUT!)
```
Starting Spark job with 5-minute timeout...
INFO spark.SparkContext: Running Spark version 3.4.0
INFO yarn.Client: Application report for application_XXX (state: RUNNING) ◄── Should reach RUNNING!
INFO scheduler.TaskSetManager: Finished task 0.0
✓ Spark job execution completed
```

---

## 🎯 Why It Was Stuck

### Root Causes:
1. **YARN Resource Exhaustion** - Previous apps still holding resources
2. **Too Many Executors** - Requested 2 executors but only 1 node available
3. **Memory Pressure** - 1G per executor + overhead = not enough
4. **No Timeout** - Pipeline waited forever

### Solutions Applied:
- ✅ Kill old applications
- ✅ Reduce to 1 executor
- ✅ Lower memory to 512M
- ✅ Add 5-minute timeout
- ✅ Check resources first

---

## 📋 One-Liner Quick Fix

If you just want to quickly clean up and restart:

```bash
# From your laptop:
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97 \
  "sudo -u consultant yarn application -list -appStates ACCEPTED | \
   grep 'application_' | awk '{print \$1}' | \
   xargs -I {} sudo -u consultant yarn application -kill {}"

# Wait 10 seconds
sleep 10

# Trigger Jenkins build
curl -u "consultant:WelcomeItc@2026" \
  -H "$(curl -s -u consultant:WelcomeItc@2026 --cookie-jar /tmp/jc \
       'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')" \
  --cookie /tmp/jc \
  'http://51.24.13.205:8081/job/TfL_Spark_Pipeline/buildWithParameters?SPARK_SCRIPT=simple_spark_wordcount.py&NUM_EXECUTORS=1&EXECUTOR_MEMORY=512M&EXECUTOR_CORES=1'
```

---

## 🔍 Troubleshooting

### Still Stuck in ACCEPTED?

**Check YARN UI:**
http://13.41.167.97:8088/cluster/apps

Look for:
- **Applications in ACCEPTED state** - Kill them
- **0 nodes active** - Restart NodeManager
- **0 MB available** - Reduce memory or restart services

**Check Cloudera Manager:**
http://13.41.167.97:7180/ (Admin/Admin@2026)

1. Go to: **Clusters > Cluster 1 > YARN**
2. Check: **NodeManager** is green (running)
3. If not: Click **Actions > Restart**

### Timeout Error?

If job times out after 5 minutes:
1. Increase timeout in `Jenkinsfile`: `timeout(time: 10, unit: 'MINUTES')`
2. Or run Spark job manually to debug:

```bash
ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97
sudo su - consultant
cd /home/consultant/uttam/TFL_Project_Demo

spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 1 \
  --executor-memory 512M \
  --executor-cores 1 \
  src/spark/simple_spark_wordcount.py
```

### Memory Error?

If still getting memory errors:
```bash
# Reduce even further:
NUM_EXECUTORS: 1
EXECUTOR_MEMORY: 256M  ◄── Half of 512M
```

---

## 📚 Scripts Available

I've created these scripts for you:

1. **`restart_spark_pipeline.sh`** - Automated recovery (kills apps + rebuilds)
2. **`fix_yarn_stuck.sh`** - Manual YARN cleanup
3. **Updated `Jenkinsfile`** - With timeout + resource checks

All committed to GitHub: https://github.com/uttamraj9/TFL_Project_Demo

---

## ✅ Success Checklist

Before running again:

- [ ] SSH to Cloudera works: `ssh -i ~/Downloads/Training/test_key.pem ec2-user@13.41.167.97`
- [ ] No stuck YARN apps: `yarn application -list -appStates ACCEPTED` shows 0
- [ ] NodeManager running: `yarn node -list` shows 1 node RUNNING
- [ ] Memory available: `free -h` shows > 1GB available
- [ ] GitHub updated: Pipeline job sees latest Jenkinsfile with timeout
- [ ] Reduced resources: NUM_EXECUTORS=1, EXECUTOR_MEMORY=512M

Then rebuild in Jenkins!

---

## 🎉 Expected Result

With fixes applied:

```
=========================================
Stage 1: Git Checkout
=========================================
✓ Checked out: 8948e75

=========================================
Stage 4: Check YARN Resource Availability
=========================================
Total Nodes: 1
Node-Id: localhost:8041    RUNNING
✓ YARN resources checked

=========================================
Stage 6: Execute PySpark Job
=========================================
Starting Spark job with 5-minute timeout...
INFO yarn.Client: Application report (state: RUNNING)
✓ Spark job execution completed

=========================================
✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓
=========================================
```

**Duration:** ~2-3 minutes (not hanging!)

---

**Created:** June 3, 2026  
**Issue:** Spark job stuck in YARN ACCEPTED state  
**Fix:** Kill apps + reduce resources + add timeout  
**Status:** Ready to test ✅
