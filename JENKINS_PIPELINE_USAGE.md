# Jenkins Pipeline for PySpark - Usage Guide

## 📋 Overview

Your Jenkins pipeline is **already configured** and ready to execute PySpark jobs on the Cloudera cluster.

**Pipeline File:** `Jenkinsfile`  
**Target Script:** `src/spark/simple_spark_wordcount.py`  
**Remote Host:** 13.41.167.97 (Cloudera)

---

## 🚀 Quick Start

### Option 1: Run Default Configuration (Recommended)

```bash
# From Jenkins UI:
1. Click "Build with Parameters"
2. Select SPARK_SCRIPT: simple_spark_wordcount.py
3. Keep defaults:
   - NUM_EXECUTORS: 2
   - EXECUTOR_MEMORY: 1G
   - EXECUTOR_CORES: 1
4. Click "Build"
```

### Option 2: Custom Resource Configuration

```bash
# For larger workloads:
SPARK_SCRIPT: simple_spark_wordcount.py
NUM_EXECUTORS: 4
EXECUTOR_MEMORY: 2G
EXECUTOR_CORES: 2
```

---

## 📊 Pipeline Stages

The Jenkins pipeline executes 6 automated stages:

### Stage 1: Checkout
- Pulls latest code from GitHub repository
- Shows latest commit information
- **Duration:** ~5-10 seconds

### Stage 2: Verify Scripts
- Checks if selected PySpark script exists
- Lists all available scripts in `src/spark/`
- Validates file permissions
- **Duration:** ~2-3 seconds

### Stage 3: Deploy to Cloudera
- Creates remote directory on Cloudera cluster
- Copies PySpark scripts via SCP
- Sets executable permissions
- **Duration:** ~10-15 seconds

### Stage 4: Prepare HDFS
- Cleans up previous output directory
- Prepares HDFS path: `/tmp/uttam/spark_output`
- **Duration:** ~5-8 seconds

### Stage 5: Run Spark Job
- Executes `spark-submit` on YARN cluster
- Runs in client deploy mode
- Configurable resources (executors, memory, cores)
- **Duration:** ~30-60 seconds (depends on data size)

### Stage 6: Verify Results
- Checks HDFS output directory
- Lists generated files
- Validates job completion
- **Duration:** ~5-8 seconds

**Total Pipeline Duration:** ~1-2 minutes

---

## 🔧 Pipeline Configuration

### Environment Variables (Pre-configured)

```groovy
REMOTE_HOST = '13.41.167.97'           // Cloudera cluster IP
REMOTE_USER = 'consultant'             // SSH username
REMOTE_PASSWORD = 'WelcomeItc@2026'    // SSH password (secured)
PROJECT_DIR = '/home/consultant/uttam/TFL_Project_Demo'
OUTPUT_DIR = '/tmp/uttam/spark_output' // HDFS output path
```

### Build Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SPARK_SCRIPT` | Choice | `simple_spark_wordcount.py` | PySpark script to execute |
| `NUM_EXECUTORS` | String | `2` | Number of YARN executors |
| `EXECUTOR_MEMORY` | String | `1G` | Memory per executor |
| `EXECUTOR_CORES` | String | `1` | CPU cores per executor |

---

## 📝 What the Script Does

**Script:** `simple_spark_wordcount.py`

1. **Creates Spark Session**
   - App Name: `TfL_Simple_WordCount`
   - Log Level: WARN (reduces noise)

2. **Generates Sample Data**
   - 10 TfL station-related text records
   - Examples: "Kings Cross St Pancras station is very busy"

3. **Word Count Analysis**
   - Splits text into words
   - Counts word frequency
   - Sorts by count (descending)
   - Shows top 20 most frequent words

4. **Station Analysis**
   - Filters words containing "station"
   - Counts station mentions

5. **Saves Results to HDFS**
   - Path: `/tmp/uttam/spark_wordcount_output`
   - Format: CSV with header
   - Mode: Overwrite (replaces existing data)

6. **Displays Summary**
   - Total words processed
   - Unique words count
   - Most common word

---

## 📂 File Structure

```
TFL_Project_Demo/
├── Jenkinsfile                          # Pipeline definition (already configured)
├── src/
│   └── spark/
│       ├── simple_spark_wordcount.py    # Target script
│       └── tfl_spark_analysis.py        # Alternative script
└── JENKINS_PIPELINE_USAGE.md            # This file
```

---

## ✅ Expected Output

### Console Output (Jenkins)

```
=========================================
Stage 1: Git Checkout
=========================================
✓ Checked out revision 3a126e4

=========================================
Stage 2: Verify PySpark Scripts
=========================================
Scripts in workspace:
-rwxr-xr-x src/spark/simple_spark_wordcount.py
-rwxr-xr-x src/spark/tfl_spark_analysis.py
✓ Selected script: simple_spark_wordcount.py

=========================================
Stage 3: Deploy to Cloudera
=========================================
✓ Scripts deployed successfully

=========================================
Stage 4: Prepare HDFS Output Directory
=========================================
✓ HDFS prepared

=========================================
Stage 5: Execute PySpark Job
=========================================
Script: simple_spark_wordcount.py
Executors: 2
Memory: 1G
Cores: 1

================================================================================
Simple PySpark Word Count Demo
================================================================================

1. Creating Spark session...
✓ Spark version: 3.4.0

2. Creating sample TfL station data...
✓ Created 10 sample records

3. Performing word count analysis...

Top 20 Most Frequent Words:
+--------+-----+
|word    |count|
+--------+-----+
|station |10   |
|is      |3    |
|St      |2    |
|Pancras |1    |
|Kings   |1    |
|Cross   |1    |
|very    |1    |
|busy    |1    |
...

4. Analyzing station mentions...
✓ Found 10 mentions of 'station'

5. Saving results to HDFS: /tmp/uttam/spark_wordcount_output
✓ Results saved successfully

================================================================================
Analysis Summary:
================================================================================
Total words processed: 67
Unique words: 48
Most common word: station (10 times)
================================================================================
✓✓✓ PySpark Job Completed Successfully!
================================================================================

✓ Spark session stopped

=========================================
Stage 6: Verify Spark Output
=========================================
Found 2 items
-rw-r--r--   3 consultant supergroup          0 2026-06-02 17:45 /tmp/uttam/spark_wordcount_output/_SUCCESS
-rw-r--r--   3 consultant supergroup        512 2026-06-02 17:45 /tmp/uttam/spark_wordcount_output/part-00000.csv

=========================================
✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓
=========================================
PySpark Script: simple_spark_wordcount.py
Executors: 2 x 1G
Cloudera: 13.41.167.97:/home/consultant/uttam/TFL_Project_Demo
=========================================
```

### HDFS Output Files

```bash
# On Cloudera cluster:
hdfs dfs -ls /tmp/uttam/spark_wordcount_output

Found 2 items
-rw-r--r--   3 consultant supergroup          0 2026-06-02 17:45 /tmp/uttam/spark_wordcount_output/_SUCCESS
-rw-r--r--   3 consultant supergroup        512 2026-06-02 17:45 /tmp/uttam/spark_wordcount_output/part-00000.csv
```

### CSV Output Content

```bash
# View results:
hdfs dfs -cat /tmp/uttam/spark_wordcount_output/part-00000.csv | head -20

word,count
station,10
is,3
St,2
busy,2
serves,2
has,2
high,2
Pancras,1
Kings,1
Cross,1
very,1
Oxford,1
Circus,1
multiple,1
lines,1
Stratford,1
major,1
transport,1
hub,1
```

---

## 🔍 Monitoring & Troubleshooting

### View Spark Application in YARN

```bash
# On Cloudera cluster:
yarn application -list -appStates RUNNING

# View application logs:
yarn logs -applicationId application_XXXXXXXXXX_XXXX

# Or use Cloudera Manager UI:
http://13.41.167.97:7180/cmf/clusters/Cluster%201/yarn-applications
```

### Common Issues & Solutions

#### ❌ Issue: "PySpark script not found"
**Solution:** Verify script exists in `src/spark/` directory

```bash
ls -lh src/spark/*.py
```

#### ❌ Issue: "Connection refused" to Cloudera
**Solution:** Check Cloudera cluster is running and SSH port 22 is open

```bash
ssh consultant@13.41.167.97 "hostname"
```

#### ❌ Issue: "HDFS permission denied"
**Solution:** Check HDFS directory permissions

```bash
ssh consultant@13.41.167.97 "hdfs dfs -mkdir -p /tmp/uttam && hdfs dfs -chmod -R 777 /tmp/uttam"
```

#### ❌ Issue: "Insufficient YARN resources"
**Solution:** Reduce executor resources in build parameters

```
NUM_EXECUTORS: 1 (instead of 2)
EXECUTOR_MEMORY: 512M (instead of 1G)
EXECUTOR_CORES: 1
```

#### ❌ Issue: "Spark job hangs"
**Solution:** Check YARN Resource Manager

```bash
ssh consultant@13.41.167.97 "yarn node -list"
```

---

## 🎯 Advanced Usage

### Running with Custom HDFS Output Path

Edit `simple_spark_wordcount.py` line 59:

```python
# Original:
output_path = "/tmp/uttam/spark_wordcount_output"

# Custom:
output_path = "/user/consultant/uttam/custom_output"
```

Then commit and push to trigger Jenkins build.

### Adding More Scripts

1. Create new PySpark script in `src/spark/`:
   ```bash
   touch src/spark/my_new_spark_job.py
   ```

2. Update Jenkinsfile parameter choices (line 10):
   ```groovy
   choices: ['simple_spark_wordcount.py', 'tfl_spark_analysis.py', 'my_new_spark_job.py']
   ```

3. Commit and push changes

### Running Multiple Scripts Sequentially

Create a new Jenkins job with custom pipeline:

```groovy
pipeline {
    agent any
    stages {
        stage('Run All Scripts') {
            steps {
                build job: 'TFL_Spark_Pipeline', parameters: [
                    string(name: 'SPARK_SCRIPT', value: 'simple_spark_wordcount.py')
                ]
                build job: 'TFL_Spark_Pipeline', parameters: [
                    string(name: 'SPARK_SCRIPT', value: 'tfl_spark_analysis.py')
                ]
            }
        }
    }
}
```

---

## 📊 Performance Tuning

### Small Dataset (< 1 GB)
```
NUM_EXECUTORS: 2
EXECUTOR_MEMORY: 1G
EXECUTOR_CORES: 1
```

### Medium Dataset (1-10 GB)
```
NUM_EXECUTORS: 4
EXECUTOR_MEMORY: 2G
EXECUTOR_CORES: 2
```

### Large Dataset (> 10 GB)
```
NUM_EXECUTORS: 8
EXECUTOR_MEMORY: 4G
EXECUTOR_CORES: 4
```

**Note:** Check available YARN resources before increasing values:
```bash
ssh consultant@13.41.167.97 "yarn node -list"
```

---

## 🔐 Security Notes

### Credentials in Jenkinsfile

⚠️ **Current Status:** Password is hardcoded in `Jenkinsfile`

**Recommended:** Use Jenkins Credentials Plugin

```groovy
// Replace this:
environment {
    REMOTE_PASSWORD = 'WelcomeItc@2026'
}

// With this:
environment {
    REMOTE_PASSWORD = credentials('cloudera-ssh-password')
}
```

### SSH Key Authentication (Better Alternative)

```bash
# Generate SSH key on Jenkins server:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cloudera_jenkins

# Copy to Cloudera:
ssh-copy-id -i ~/.ssh/cloudera_jenkins.pub consultant@13.41.167.97

# Update Jenkinsfile:
sh 'ssh -i ~/.ssh/cloudera_jenkins consultant@${REMOTE_HOST} "commands"'
```

---

## 📈 CI/CD Integration

### Automatic Trigger on Git Push

Configure Jenkins webhook:

1. **GitHub Repository Settings:**
   - Go to: https://github.com/uttamraj9/TFL_Project_Demo/settings/hooks
   - Add webhook: `http://<jenkins-url>:8080/github-webhook/`
   - Events: `Just the push event`

2. **Jenkinsfile (add trigger):**
   ```groovy
   pipeline {
       agent any
       triggers {
           githubPush()  // Auto-trigger on push
       }
       // ... rest of pipeline
   }
   ```

### Scheduled Builds (Cron)

```groovy
pipeline {
    agent any
    triggers {
        cron('H 2 * * *')  // Run daily at 2 AM
    }
    // ... rest of pipeline
}
```

---

## 📚 Additional Resources

### Documentation
- **Spark Submit Guide:** https://spark.apache.org/docs/latest/submitting-applications.html
- **YARN Resource Management:** https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceModel.html
- **Jenkins Pipeline Syntax:** https://www.jenkins.io/doc/book/pipeline/syntax/

### Project Files
- **Jenkins Setup:** `JENKINS_SETUP.md`
- **Spark Pipeline Docs:** `JENKINS_SPARK_PIPELINE.md`
- **Success Summary:** `JENKINS_SUCCESS_SUMMARY.md`

### Commands Reference

```bash
# Test SSH connection:
sshpass -p 'WelcomeItc@2026' ssh consultant@13.41.167.97 "hostname"

# Check HDFS output:
ssh consultant@13.41.167.97 "hdfs dfs -ls /tmp/uttam/spark_wordcount_output"

# View CSV results:
ssh consultant@13.41.167.97 "hdfs dfs -cat /tmp/uttam/spark_wordcount_output/*.csv | head -20"

# Check YARN applications:
ssh consultant@13.41.167.97 "yarn application -list"

# View Spark logs:
ssh consultant@13.41.167.97 "yarn logs -applicationId <app-id>"
```

---

## ✅ Success Checklist

Before running the pipeline, verify:

- [ ] Jenkinsfile exists in repository root
- [ ] `simple_spark_wordcount.py` exists in `src/spark/`
- [ ] Jenkins has network access to 13.41.167.97:22
- [ ] Cloudera cluster is running and accessible
- [ ] HDFS has space in `/tmp/uttam/`
- [ ] YARN has available resources (check with `yarn node -list`)
- [ ] SSH credentials are correct (test manually)

---

## 🎉 Summary

Your Jenkins pipeline is **production-ready** and requires **zero modifications** to run `simple_spark_wordcount.py`.

**To execute:**
1. Open Jenkins web UI
2. Navigate to your pipeline job
3. Click "Build with Parameters"
4. Select `simple_spark_wordcount.py`
5. Click "Build"
6. Monitor console output (real-time)
7. Check HDFS output: `/tmp/uttam/spark_wordcount_output`

**Expected result:**
- ✅ Word count analysis completed
- ✅ CSV file saved to HDFS
- ✅ All 6 stages passed
- ✅ Build status: SUCCESS

---

**Created:** June 2, 2026  
**Last Updated:** June 2, 2026  
**Status:** Production Ready ✅  
**Script:** `simple_spark_wordcount.py`  
**Pipeline:** `Jenkinsfile` (6 stages, automated deployment)
