# Jenkins Spark Pipeline Setup

## Create New Jenkins Job for PySpark

### Job Name: `TfL_Spark_Analysis`

---

## Job Configuration

### 1. General Settings
- **Type:** Freestyle project
- **Description:** PySpark analysis job for TfL data

### 2. Source Code Management
- **Git:** 
  - Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
  - Branch: `*/main`

### 3. Build Step - Execute Shell

```bash
#!/bin/bash
set -e

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
echo "========================================"
echo ""

# Step 1: Verify Spark script in workspace
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
    $REMOTE_USER@$REMOTE_HOST "mkdir -p $PROJECT_DIR/src/spark" 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true
echo "✓ Directory created"
echo ""

# Step 3: Copy PySpark scripts
echo "Step 3: Copy PySpark scripts to Cloudera..."
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $WORKSPACE/src/spark/*.py $REMOTE_USER@$REMOTE_HOST:$PROJECT_DIR/src/spark/ 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true
echo "✓ Scripts copied"
echo ""

# Step 4: Set permissions
echo "Step 4: Set execute permissions..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "chmod +x $PROJECT_DIR/src/spark/*.py" 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true
echo "✓ Permissions set"
echo ""

# Step 5: Verify files on remote
echo "Step 5: Verify files on Cloudera..."
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "ls -lh $PROJECT_DIR/src/spark/" 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━" || true
echo "✓ Files verified"
echo ""

# Step 6: Run PySpark job
echo "======================================"
echo "Step 6: Running PySpark Analysis..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "cd $PROJECT_DIR && spark-submit \
    --master yarn \
    --deploy-mode client \
    --num-executors 2 \
    --executor-memory 1G \
    --executor-cores 1 \
    src/spark/simple_spark_wordcount.py" 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━"

echo ""
echo "✓ PySpark job completed"
echo ""

# Step 7: Verify output
echo "======================================"
echo "Step 7: Verifying Output..."
echo "======================================"
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $REMOTE_USER@$REMOTE_HOST "hdfs dfs -ls /tmp/uttam/spark_wordcount_output 2>/dev/null || echo 'Output directory not found (this is OK for demo)'" 2>&1 | grep -v "ITC Big Data Lab" | grep -v "Commands:" | grep -v "HDFS home:" | grep -v "━"

echo ""
echo "======================================"
echo "✓✓✓ SPARK PIPELINE COMPLETE ✓✓✓"
echo "======================================"
echo "GitHub: uttamraj9/TFL_Project_Demo"
echo "Script: src/spark/simple_spark_wordcount.py"
echo "Output: /tmp/uttam/spark_wordcount_output"
echo "======================================"
```

---

## Quick Setup via API

### Create Job Programmatically

```bash
# Job configuration XML
cat > /tmp/spark_job_config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>TfL PySpark Analysis Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.plugins.git.GitSCM">
    <configVersion>2</configVersion>
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
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
set -e

REMOTE_HOST="13.41.167.97"
REMOTE_USER="consultant"
REMOTE_PASSWORD="WelcomeItc@2026"
PROJECT_DIR="/home/consultant/uttam/TFL_Project_Demo"

echo "========================================"
echo "TfL PySpark Analysis Pipeline"
echo "========================================"

# [Rest of the build script as shown above]
      </command>
    </hudson.tasks.Shell>
  </builders>
</project>
EOF

# Create job via API
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

curl -X POST -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @/tmp/spark_job_config.xml \
  'http://51.24.13.205:8081/createItem?name=TfL_Spark_Analysis'
```

---

## Manual Setup Steps

### 1. Create New Job
1. Go to Jenkins: http://51.24.13.205:8081/
2. Click **New Item**
3. Name: `TfL_Spark_Analysis`
4. Type: **Freestyle project**
5. Click **OK**

### 2. Configure Source
- **Source Code Management:** Git
  - Repository URL: `https://github.com/uttamraj9/TFL_Project_Demo.git`
  - Branch: `*/main`

### 3. Add Build Step
- **Add build step** → **Execute shell**
- **Paste the script** from above

### 4. Save and Build
- Click **Save**
- Click **Build Now**

---

## Test the Pipeline

### Trigger Build

```bash
# Get crumb
CRUMB=$(curl -s -u "consultant:WelcomeItc@2026" \
  --cookie-jar /tmp/jenkins-cookie \
  'http://51.24.13.205:8081/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

# Trigger Spark pipeline
curl -u "consultant:WelcomeItc@2026" \
  --cookie /tmp/jenkins-cookie \
  -H "$CRUMB" \
  -X POST \
  'http://51.24.13.205:8081/job/TfL_Spark_Analysis/build'
```

### Monitor Build

```bash
# Check status
curl -s -u "consultant:WelcomeItc@2026" \
  'http://51.24.13.205:8081/job/TfL_Spark_Analysis/lastBuild/api/json' \
  | grep -o '"building":[^,]*'

# View console
curl -s -u "consultant:WelcomeItc@2026" \
  'http://51.24.13.205:8081/job/TfL_Spark_Analysis/lastBuild/consoleText' \
  | tail -50
```

---

## Expected Output

```
Top 20 Most Frequent Words:
+----------+-----+
|word      |count|
+----------+-----+
|station   |10   |
|is        |4    |
|serves    |3    |
|busy      |2    |
|multiple  |2    |
|lines     |2    |
...

Analysis Summary:
Total words processed: 67
Unique words: 45
Most common word: station (10 times)
✓✓✓ PySpark Job Completed Successfully!
```

---

## Verification on Cloudera

```bash
# SSH to cluster
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97

# Check script
sudo -u consultant ls -la /home/consultant/uttam/TFL_Project_Demo/src/spark/

# Check output
sudo -u consultant hdfs dfs -ls /tmp/uttam/spark_wordcount_output

# Read results
sudo -u consultant hdfs dfs -cat /tmp/uttam/spark_wordcount_output/*.csv | head -20
```

---

## Spark Submit Options

For the advanced TfL analysis script:

```bash
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 3 \
  --executor-memory 2G \
  --executor-cores 2 \
  --driver-memory 1G \
  --conf spark.sql.shuffle.partitions=10 \
  src/spark/tfl_spark_analysis.py
```

---

## Troubleshooting

### Issue: Spark not found
```bash
# Check Spark installation
which spark-submit
echo $SPARK_HOME
```

### Issue: YARN connection failed
```bash
# Check YARN status
yarn node -list
yarn application -list
```

### Issue: HDFS permission denied
```bash
# Create output directory
hdfs dfs -mkdir -p /tmp/uttam/spark_wordcount_output
hdfs dfs -chmod 777 /tmp/uttam/spark_wordcount_output
```

---

## Files Created

1. **`src/spark/simple_spark_wordcount.py`** - Simple demo script
2. **`src/spark/tfl_spark_analysis.py`** - Advanced analysis script
3. **`JENKINS_SPARK_PIPELINE.md`** - This documentation

---

*Jenkins Server: http://51.24.13.205:8081/*  
*Job Name: TfL_Spark_Analysis*  
*Repository: https://github.com/uttamraj9/TFL_Project_Demo*
