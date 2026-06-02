# TfL PySpark Pipeline Architecture

## 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB REPOSITORY                            │
│                 https://github.com/uttamraj9/TFL_Project_Demo       │
│                                                                       │
│  ┌────────────────┐  ┌────────────────────────────────────────┐    │
│  │  Jenkinsfile   │  │  src/spark/                             │    │
│  │  (Pipeline)    │  │  ├── simple_spark_wordcount.py          │    │
│  │                │  │  └── tfl_spark_analysis.py              │    │
│  └────────────────┘  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Git Clone (Stage 1)
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       JENKINS SERVER                                 │
│                    http://51.24.13.205:8081                          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │           DECLARATIVE PIPELINE EXECUTION                      │  │
│  │                                                                │  │
│  │  Stage 1: Checkout          ✓ Pull from GitHub               │  │
│  │  Stage 2: Verify Scripts    ✓ Check .py files                │  │
│  │  Stage 3: Deploy            ──► SSH/SCP to Cloudera           │  │
│  │  Stage 4: Prepare HDFS      ──► Clean output directory        │  │
│  │  Stage 5: Run Spark Job     ──► spark-submit on YARN          │  │
│  │  Stage 6: Verify Results    ✓ Check HDFS output              │  │
│  │                                                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH/SCP (sshpass)
                                    │ User: consultant
                                    │ Pass: WelcomeItc@2026
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     CLOUDERA CLUSTER                                 │
│                       13.41.167.97                                   │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Local Directory: /home/consultant/uttam/TFL_Project_Demo  │    │
│  │  ├── src/spark/simple_spark_wordcount.py (deployed)        │    │
│  │  └── src/spark/tfl_spark_analysis.py (deployed)            │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │               YARN RESOURCE MANAGER                          │    │
│  │                                                              │    │
│  │  Spark Application: TfL_Simple_WordCount                    │    │
│  │  ├── Driver: Client mode (runs on edge node)               │    │
│  │  ├── Executors: 2 containers                               │    │
│  │  ├── Memory: 1G per executor                               │    │
│  │  └── Cores: 1 per executor                                 │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                │                                     │
│                                │ Writes results                      │
│                                ▼                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                      HDFS                                   │    │
│  │  /tmp/uttam/spark_wordcount_output/                        │    │
│  │  ├── _SUCCESS (marker file)                                │    │
│  │  └── part-00000.csv (word counts)                          │    │
│  │                                                              │    │
│  │  Sample Output:                                             │    │
│  │  ┌─────────────────────────────────────────────┐           │    │
│  │  │ word,count                                  │           │    │
│  │  │ station,10                                   │           │    │
│  │  │ is,3                                         │           │    │
│  │  │ St,2                                         │           │    │
│  │  │ busy,2                                       │           │    │
│  │  │ ...                                          │           │    │
│  │  └─────────────────────────────────────────────┘           │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Pipeline Flow Diagram

```
 START
   │
   ▼
┌─────────────────────┐
│  Stage 1: Checkout  │
│  ─────────────────  │
│  • Clone GitHub repo │
│  • Checkout main     │
│  • Show commit hash  │
└─────────────────────┘
   │ ✓
   ▼
┌─────────────────────┐
│ Stage 2: Verify     │
│ ────────────────    │
│ • Check .py exists   │
│ • List all scripts   │
│ • Validate selection │
└─────────────────────┘
   │ ✓
   ▼
┌─────────────────────┐
│ Stage 3: Deploy     │
│ ────────────────    │
│ • SSH to Cloudera    │
│ • Create directories │
│ • SCP Python scripts │
│ • Set permissions    │
└─────────────────────┘
   │ ✓
   ▼
┌─────────────────────┐
│ Stage 4: Prepare    │
│ ────────────────    │
│ • Clean HDFS output  │
│ • Remove old results │
│ • Ready for new run  │
└─────────────────────┘
   │ ✓
   ▼
┌─────────────────────┐
│ Stage 5: Spark Job  │◄────── MAIN PROCESSING
│ ────────────────    │
│ • Submit to YARN     │        ┌──────────────────┐
│ • Run PySpark script │        │  Spark Execution │
│ • Wait for completion│───────▶│  ───────────────  │
│ • Capture logs       │        │  • Split words    │
└─────────────────────┘        │  • Count frequency│
   │ ✓                          │  • Aggregate data │
   ▼                            │  • Save to HDFS   │
┌─────────────────────┐        └──────────────────┘
│ Stage 6: Verify     │
│ ────────────────    │
│ • List HDFS files    │
│ • Check _SUCCESS     │
│ • Validate output    │
└─────────────────────┘
   │ ✓
   ▼
┌─────────────────────┐
│  POST: Success      │
│  ──────────────     │
│  • Print summary     │
│  • Show metrics      │
│  • Mark build SUCCESS│
└─────────────────────┘
   │
   ▼
  END
```

---

## 🎯 Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                    INPUT DATA (In-Memory)                       │
│                                                                  │
│  Sample TfL Station Data:                                      │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ "Kings Cross St Pancras station is very busy"           │ │
│  │ "Oxford Circus station serves multiple lines"           │ │
│  │ "Stratford station is a major transport hub"            │ │
│  │ "Waterloo station has high passenger volume"            │ │
│  │ ... (10 records total)                                   │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ spark.createDataFrame()
                             ▼
┌────────────────────────────────────────────────────────────────┐
│                   SPARK DATAFRAME (df)                          │
│                                                                  │
│  Schema: [text: string]                                        │
│  Rows: 10                                                       │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ explode(split(col("text"), " "))
                             ▼
┌────────────────────────────────────────────────────────────────┐
│                  WORDS DATAFRAME (words_df)                     │
│                                                                  │
│  Schema: [word: string]                                        │
│  Sample:                                                        │
│  ┌──────────┐                                                  │
│  │   word   │                                                  │
│  ├──────────┤                                                  │
│  │  Kings   │                                                  │
│  │  Cross   │                                                  │
│  │  St      │                                                  │
│  │  Pancras │                                                  │
│  │  station │                                                  │
│  │  is      │                                                  │
│  │  very    │                                                  │
│  │  busy    │                                                  │
│  │  ...     │                                                  │
│  └──────────┘                                                  │
│  Total: 67 words                                               │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ groupBy("word").count()
                             │ orderBy(col("count").desc())
                             ▼
┌────────────────────────────────────────────────────────────────┐
│              WORD COUNTS DATAFRAME (word_counts)                │
│                                                                  │
│  Schema: [word: string, count: long]                           │
│  Sample (Top 10):                                              │
│  ┌──────────┬───────┐                                          │
│  │   word   │ count │                                          │
│  ├──────────┼───────┤                                          │
│  │ station  │  10   │  ◄── Most frequent                      │
│  │ is       │   3   │                                          │
│  │ St       │   2   │                                          │
│  │ busy     │   2   │                                          │
│  │ serves   │   2   │                                          │
│  │ Kings    │   1   │                                          │
│  │ Cross    │   1   │                                          │
│  │ Pancras  │   1   │                                          │
│  │ ...      │  ...  │                                          │
│  └──────────┴───────┘                                          │
│  Total: 48 unique words                                        │
└────────────────────────────────────────────────────────────────┘
                             │
                             │ write.mode("overwrite")
                             │ .option("header", "true")
                             │ .csv(output_path)
                             ▼
┌────────────────────────────────────────────────────────────────┐
│               HDFS OUTPUT (CSV Format)                          │
│                                                                  │
│  Path: /tmp/uttam/spark_wordcount_output/                     │
│  Files:                                                         │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ _SUCCESS (0 bytes)                    ◄── Success marker│ │
│  │ part-00000.csv (512 bytes)            ◄── Actual data   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Content of part-00000.csv:                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ word,count                                               │ │
│  │ station,10                                               │ │
│  │ is,3                                                     │ │
│  │ St,2                                                     │ │
│  │ busy,2                                                   │ │
│  │ serves,2                                                 │ │
│  │ ...                                                      │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

---

## 🏢 Infrastructure Components

### Jenkins Server
```
┌──────────────────────────────────────┐
│   Jenkins Master Node                │
│   ─────────────────                  │
│   Host: 51.24.13.205                 │
│   Port: 8081                          │
│   User: consultant                    │
│                                       │
│   Installed Plugins:                  │
│   • Git Plugin                        │
│   • Pipeline Plugin                   │
│   • GitHub Integration                │
│                                       │
│   System Tools:                       │
│   • sshpass (SSH automation)          │
│   • git (Source control)              │
│   • curl (API testing)                │
└──────────────────────────────────────┘
```

### Cloudera Cluster
```
┌──────────────────────────────────────────────────────────┐
│   Cloudera Hadoop Cluster (Single Node / Pseudo-dist)    │
│   ────────────────────────────────────────────────       │
│   Host: 13.41.167.97                                      │
│   User: consultant                                        │
│                                                           │
│   Hadoop Components:                                      │
│   ┌────────────────────────────────────────────────┐    │
│   │ HDFS        │ Distributed file system           │    │
│   │ YARN        │ Resource manager                   │    │
│   │ Spark 3.4.0 │ Distributed processing engine      │    │
│   └────────────────────────────────────────────────┘    │
│                                                           │
│   Key Directories:                                        │
│   • /home/consultant/uttam/TFL_Project_Demo (local)      │
│   • /tmp/uttam/ (HDFS)                                   │
│   • hdfs://namenode/ (HDFS root)                         │
└──────────────────────────────────────────────────────────┘
```

### GitHub Repository
```
┌─────────────────────────────────────────────────┐
│  Repository: uttamraj9/TFL_Project_Demo         │
│  ──────────────────────────────────────         │
│  Branch: main                                    │
│  Visibility: PUBLIC                              │
│                                                  │
│  Key Files:                                      │
│  • Jenkinsfile (pipeline definition)            │
│  • src/spark/*.py (PySpark scripts)             │
│  • CLAUDE.md (project docs)                     │
│  • README.md (getting started)                  │
│                                                  │
│  Commits: 5                                      │
│  Latest: 3a126e4 (June 2, 2026)                 │
└─────────────────────────────────────────────────┘
```

---

## 🔐 Authentication Flow

```
┌──────────────┐                      ┌──────────────┐
│   Jenkins    │                      │  Cloudera    │
│   Server     │                      │  Cluster     │
└──────┬───────┘                      └──────┬───────┘
       │                                      │
       │ 1. SSH Connection                    │
       │────────────────────────────────────▶ │
       │    sshpass -p 'WelcomeItc@2026'      │
       │    ssh consultant@13.41.167.97       │
       │                                      │
       │ 2. Authentication                    │
       │ ◀───────────────────────────────────│
       │    Password: WelcomeItc@2026         │
       │    User: consultant                  │
       │                                      │
       │ 3. Command Execution                 │
       │────────────────────────────────────▶ │
       │    mkdir -p ~/uttam/TFL_Project_Demo │
       │                                      │
       │ 4. File Transfer (SCP)               │
       │────────────────────────────────────▶ │
       │    scp *.py consultant@13.41.167.97: │
       │                                      │
       │ 5. Spark Submit                      │
       │────────────────────────────────────▶ │
       │    spark-submit --master yarn ...    │
       │                                      │
       │ 6. YARN Execution                    │
       │                   ┌────────────────┐ │
       │                   │  YARN RM       │ │
       │                   │  • Schedule    │ │
       │                   │  • Monitor     │ │
       │                   │  • Report back │ │
       │                   └────────────────┘ │
       │                                      │
       │ 7. Results                           │
       │ ◀───────────────────────────────────│
       │    Spark output logs                 │
       │    HDFS file paths                   │
       │    Success/failure status            │
       │                                      │
```

---

## 📊 Resource Allocation

### Default Configuration
```
┌─────────────────────────────────────────────────────┐
│              YARN Resource Allocation               │
│                                                      │
│  ┌────────────────────────────────────────────┐   │
│  │  Application Master (Driver)               │   │
│  │  ────────────────────────                  │   │
│  │  Memory: 1G (default)                      │   │
│  │  Cores: 1                                  │   │
│  │  Location: Client mode (Edge node)         │   │
│  └────────────────────────────────────────────┘   │
│                                                      │
│  ┌────────────────────────────────────────────┐   │
│  │  Executor 1                                │   │
│  │  ────────────                              │   │
│  │  Memory: 1G (parameter: EXECUTOR_MEMORY)   │   │
│  │  Cores: 1 (parameter: EXECUTOR_CORES)      │   │
│  │  Tasks: Parallel processing                │   │
│  └────────────────────────────────────────────┘   │
│                                                      │
│  ┌────────────────────────────────────────────┐   │
│  │  Executor 2                                │   │
│  │  ────────────                              │   │
│  │  Memory: 1G                                │   │
│  │  Cores: 1                                  │   │
│  │  Tasks: Parallel processing                │   │
│  └────────────────────────────────────────────┘   │
│                                                      │
│  Total Resources:                                   │
│  • Total Memory: 3G (1G driver + 2x1G executors)   │
│  • Total Cores: 3 (1 driver + 2 executors)         │
│  • Parallelism: 2 executors                        │
└─────────────────────────────────────────────────────┘
```

### Configurable Parameters
```
┌──────────────────────────────────────────────────────┐
│  Parameter         │  Default  │  Range     │  Impact │
│──────────────────────────────────────────────────────│
│  NUM_EXECUTORS     │    2      │  1-10      │  High   │
│  EXECUTOR_MEMORY   │    1G     │  512M-8G   │  High   │
│  EXECUTOR_CORES    │    1      │  1-4       │  Medium │
└──────────────────────────────────────────────────────┘
```

---

## 🎯 Pipeline Parameters

### Build Parameters (Jenkins UI)

```
┌────────────────────────────────────────────────────────┐
│                 Build with Parameters                   │
│                                                          │
│  SPARK_SCRIPT:                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ ▼ simple_spark_wordcount.py                    │   │
│  │   tfl_spark_analysis.py                        │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  NUM_EXECUTORS: [ 2                            ]       │
│  Description: Number of YARN executors                  │
│                                                          │
│  EXECUTOR_MEMORY: [ 1G                         ]       │
│  Description: Memory per executor (e.g., 1G, 2G)       │
│                                                          │
│  EXECUTOR_CORES: [ 1                           ]       │
│  Description: CPU cores per executor                    │
│                                                          │
│  ┌──────────┐                                           │
│  │  Build   │                                           │
│  └──────────┘                                           │
└────────────────────────────────────────────────────────┘
```

### Parameter Usage Examples

**Minimal Resources (Dev/Test):**
```
SPARK_SCRIPT: simple_spark_wordcount.py
NUM_EXECUTORS: 1
EXECUTOR_MEMORY: 512M
EXECUTOR_CORES: 1
```

**Standard Resources (Default):**
```
SPARK_SCRIPT: simple_spark_wordcount.py
NUM_EXECUTORS: 2
EXECUTOR_MEMORY: 1G
EXECUTOR_CORES: 1
```

**High Resources (Production-like):**
```
SPARK_SCRIPT: tfl_spark_analysis.py
NUM_EXECUTORS: 4
EXECUTOR_MEMORY: 2G
EXECUTOR_CORES: 2
```

---

## 🚦 Status Monitoring

### Jenkins Console Output Flow
```
[Stage 1] ========================================
[Stage 1] Git Checkout
[Stage 1] ========================================
[Stage 1] ✓ Checked out: 3a126e4
          ↓
[Stage 2] ========================================
[Stage 2] Verify PySpark Scripts
[Stage 2] ========================================
[Stage 2] ✓ Scripts found: 2 files
          ↓
[Stage 3] ========================================
[Stage 3] Deploy to Cloudera
[Stage 3] ========================================
[Stage 3] ✓ Scripts deployed successfully
          ↓
[Stage 4] ========================================
[Stage 4] Prepare HDFS
[Stage 4] ========================================
[Stage 4] ✓ HDFS prepared
          ↓
[Stage 5] ========================================
[Stage 5] Execute PySpark Job
[Stage 5] ========================================
[Stage 5] Spark version: 3.4.0
[Stage 5] Created 10 sample records
[Stage 5] Top 20 Most Frequent Words:
[Stage 5] station: 10
[Stage 5] ✓✓✓ PySpark Job Completed Successfully!
          ↓
[Stage 6] ========================================
[Stage 6] Verify Results
[Stage 6] ========================================
[Stage 6] Found 2 items in HDFS
          ↓
[SUCCESS] ========================================
[SUCCESS] ✓✓✓ PIPELINE COMPLETED SUCCESSFULLY ✓✓✓
[SUCCESS] ========================================
```

---

## 📁 Directory Structure

### Jenkins Workspace
```
/var/lib/jenkins/workspace/TFL_Spark_Pipeline/
├── .git/
├── src/
│   └── spark/
│       ├── simple_spark_wordcount.py       ◄── Source
│       └── tfl_spark_analysis.py           ◄── Source
├── Data/
│   └── normalized/
├── Jenkinsfile                              ◄── Pipeline definition
├── CLAUDE.md
└── README.md
```

### Cloudera Local Filesystem
```
/home/consultant/uttam/TFL_Project_Demo/
└── src/
    └── spark/
        ├── simple_spark_wordcount.py       ◄── Deployed
        └── tfl_spark_analysis.py           ◄── Deployed
```

### HDFS Filesystem
```
hdfs://namenode/tmp/uttam/
└── spark_wordcount_output/
    ├── _SUCCESS                            ◄── Marker file
    └── part-00000.csv                      ◄── Results (word,count)
```

---

## 🎯 Success Criteria

### Pipeline Success Indicators

✅ **All 6 Stages Pass**
```
Stage 1: Checkout        ──► ✓ Green
Stage 2: Verify Scripts  ──► ✓ Green
Stage 3: Deploy          ──► ✓ Green
Stage 4: Prepare HDFS    ──► ✓ Green
Stage 5: Run Spark Job   ──► ✓ Green
Stage 6: Verify Results  ──► ✓ Green
```

✅ **HDFS Output Created**
```
hdfs dfs -test -e /tmp/uttam/spark_wordcount_output/_SUCCESS
# Exit code: 0 (success)
```

✅ **CSV Results Valid**
```
hdfs dfs -cat /tmp/uttam/spark_wordcount_output/*.csv | wc -l
# Expected: 49 lines (1 header + 48 unique words)
```

✅ **Spark Application Completed**
```
yarn application -list -appStates FINISHED | grep TfL_Simple_WordCount
# Status: FINISHED
# Final Status: SUCCEEDED
```

---

## 🔧 Maintenance & Operations

### Regular Tasks

**Daily:**
- Monitor Jenkins build queue
- Check HDFS disk usage: `hdfs dfs -df -h /tmp/uttam`
- Review failed builds in Jenkins UI

**Weekly:**
- Clean old HDFS outputs: `hdfs dfs -rm -r -skipTrash /tmp/uttam/spark_*_output.old`
- Backup Jenkins job configurations
- Review YARN application logs

**Monthly:**
- Update PySpark scripts from GitHub
- Check Cloudera cluster health
- Review resource utilization trends

---

## 📚 References

### Quick Links
- **GitHub Repo:** https://github.com/uttamraj9/TFL_Project_Demo
- **Jenkins UI:** http://51.24.13.205:8081/
- **Cloudera Manager:** http://13.41.167.97:7180/
- **YARN RM UI:** http://13.41.167.97:8088/

### Documentation Files
- `JENKINS_PIPELINE_USAGE.md` - Complete usage guide
- `JENKINS_SPARK_PIPELINE.md` - Spark job setup
- `JENKINS_SUCCESS_SUMMARY.md` - Build success report
- `CLAUDE.md` - Full project history

---

**Architecture Version:** 1.0  
**Last Updated:** June 2, 2026  
**Status:** Production Ready ✅
