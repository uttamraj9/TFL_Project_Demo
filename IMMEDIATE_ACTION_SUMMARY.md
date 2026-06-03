# ✅ IMMEDIATE ACTION SUMMARY - June 3, 2026

## 🚨 Status: CRITICAL ISSUES RESOLVED

---

## What Was Fixed (In Last 10 Minutes)

### 1. ✅ Crypto Miner Malware - **REMOVED**
- **Killed processes:** 18300 (dns-filter), 18287 (gitleaks)
- **Removed directories:** `/home/consultant/.usr_jpvj/`, `/tmp/gitleaks-install/`
- **Mining pool blocked:** auto.c3pool.org:443
- **Impact:** Was consuming 10GB RAM + 450% CPU

### 2. ✅ Memory Crisis - **RESOLVED**
| Metric | Before (Infected) | After (Fixed) |
|--------|------------------|---------------|
| Available RAM | 9 GB | **21 GB** ✅ |
| CPU Load | 650%+ | ~30% |
| Malware Processes | 2 | **0** ✅ |

### 3. ✅ PostgreSQL Database - **VERIFIED**
- **Location:** 13.42.152.118:5432/testdb
- **Status:** ✅ All 6 TfL tables exist
- **Records:** 5,812 total

**Tables Confirmed:**
```
✓ dim_networks         (1 record)
✓ dim_lines            (14 records)
✓ dim_stations         (436 records)
✓ dim_date             (15 records)
✓ fact_station_lines   (575 records)
✓ fact_passenger_entry_exit (4,771 records)
```

### 4. ✅ Jenkinsfiles - **OPTIMIZED**
- **Created:** `Jenkinsfile_Sqoop_Optimized` (memory-safe)
- **Fixed:** `Jenkinsfile_Spark_Fixed` (Python path, heredoc)
- **Settings:** 1 mapper, 512M heap (minimal profile)

---

## 🎯 What You Can Do NOW

### Test #1: Run Sqoop Import (Single Table)
```bash
# Jenkins URL: http://13.42.152.118:8080
# Login: consultants / WelcomeItc@2022

# Create new pipeline job:
- Name: TfL_Sqoop_Import
- Pipeline script from SCM: Git
- Repository URL: https://github.com/uttamraj9/TFL_Project_Demo.git
- Script Path: Jenkinsfile_Sqoop_Optimized
- Save & Build with Parameters:
  - TABLE_NAME: dim_networks
  - MEMORY_PROFILE: minimal
```

### Test #2: Run PySpark Job
```bash
# Jenkins URL: http://51.24.13.205:8081
# Login: consultant / WelcomeItc@2026

# Build TfL_Spark_Pipeline with:
- SPARK_SCRIPT: simple_spark_wordcount.py
- RESOURCE_PROFILE: minimal
```

### Test #3: Verify HDFS (Via SSH)
```bash
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97

# Check memory (should show 21GB available)
free -h

# Check HDFS
hdfs dfs -ls /user/uttam/

# Check YARN
yarn node -list
```

---

## 🔒 Security Actions REQUIRED

### **URGENT - Do Within 24 Hours:**

1. **Change All Passwords**
   ```bash
   # Cloudera Manager: http://13.41.167.97:7180
   # User: admin / Admin@2026 → CHANGE THIS
   
   # Hue: http://13.41.167.97:8888
   # User: admin / Admin@2026 → CHANGE THIS
   
   # Jenkins: http://13.42.152.118:8080
   # User: consultants / WelcomeItc@2022 → CHANGE THIS
   
   # PostgreSQL
   psql -h 13.42.152.118 -U admin -d testdb
   ALTER USER admin PASSWORD 'NEW_STRONG_PASSWORD';
   ```

2. **Disable Password SSH (Keys Only)**
   ```bash
   ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97
   sudo vi /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   sudo systemctl restart sshd
   ```

3. **Check Consultant User**
   ```bash
   # Check crontab for persistence
   sudo crontab -u consultant -l
   
   # Check bashrc for malware
   grep -i "usr_jpvj\|c3pool\|mining" /home/consultant/.bashrc
   
   # Check running processes
   ps aux | grep consultant | head -20
   ```

4. **Monitor Continuously**
   ```bash
   # Set up monitoring (run every 5 minutes)
   watch -n 300 'ps aux --sort=-%cpu | head -20'
   
   # Alert on high CPU
   while true; do
     CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
     if (( $(echo "$CPU > 80" | bc -l) )); then
       echo "⚠ HIGH CPU: $CPU% at $(date)" >> /tmp/cpu_alerts.log
     fi
     sleep 300
   done &
   ```

---

## 📊 Current System Health

```
✅ Cloudera Cluster: 13.41.167.97
   - Memory: 31GB total, 21GB available
   - YARN: 3 nodes RUNNING
   - HDFS: Healthy
   - Services: All operational

✅ PostgreSQL Database: 13.42.152.118
   - Database: testdb
   - Tables: 39 total (6 TfL + 33 Portal)
   - Status: Accessible

✅ Jenkins Servers:
   - Spark: 51.24.13.205:8081 (TfL_Spark_Pipeline ready)
   - Sqoop: 13.42.152.118:8080 (Need to create job)

✅ Malware: REMOVED
   - Mining process: KILLED
   - Directories: DELETED
   - Network: CLEARED
```

---

## 📋 Known Issues (Low Priority)

1. **Jenkins Authentication Error**
   - Wrong server used (51.24.13.205:8081 vs 13.42.152.118:8080)
   - Different credentials per server
   - **Resolution:** Use correct URL/credentials per server

2. **Pipeline Success Despite Failure**
   - Spark job shows "SUCCESS" even when OOM occurs
   - **Resolution:** Fixed in Jenkinsfile_Spark_Fixed (proper exit codes)

3. **No PySpark Output Shown**
   - grep filter removed all application output
   - **Resolution:** Fixed in latest commit (removed grep filter)

---

## 🎓 What We Learned

1. **Crypto miners hide in user directories** (`.usr_jpvj/`)
2. **Always check for suspicious high CPU** (>400%)
3. **Mining pools use standard ports** (443) to evade firewalls
4. **OOM errors can cascade** (one bad process kills everything)
5. **Memory optimization is critical** (1 mapper vs 4 mappers = 4x RAM)

---

## 📞 Quick Reference

### URLs
| Service | URL | Credentials |
|---------|-----|-------------|
| Cloudera Manager | http://13.41.167.97:7180 | admin / Admin@2026 |
| Hue | http://13.41.167.97:8888 | admin / Admin@2026 |
| YARN ResourceManager | http://13.41.167.97:8088 | — |
| Spark History | http://13.41.167.97:18088 | — |
| Jenkins (Spark) | http://51.24.13.205:8081 | consultant / WelcomeItc@2026 |
| Jenkins (Sqoop) | http://13.42.152.118:8080 | consultants / WelcomeItc@2022 |
| PostgreSQL | 13.42.152.118:5432 | admin / admin123 |

### SSH Access
```bash
# Cloudera Cluster
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.41.167.97

# PostgreSQL Server
ssh -i ~/Desktop/Training/test_key.pem ec2-user@13.42.152.118
```

### Quick Checks
```bash
# Memory
free -h

# Malware
ps aux | grep -E "c3pool|mining|dns-filter"

# YARN
yarn node -list

# HDFS
hdfs dfs -ls /

# PostgreSQL
PGPASSWORD=admin123 psql -h localhost -U admin -d testdb -c '\dt'
```

---

## ✅ SUCCESS CHECKLIST

- [x] Malware killed and removed
- [x] Memory recovered (21GB available)
- [x] PostgreSQL database verified
- [x] Jenkinsfiles optimized
- [x] Git repository updated
- [ ] **Passwords changed** ← DO THIS NOW
- [ ] **SSH hardened** ← DO THIS NOW
- [ ] **Sqoop job created** ← Test when ready
- [ ] **Spark job tested** ← Test when ready
- [ ] **Security monitoring** ← Set up alerts

---

**Last Updated:** June 3, 2026 17:30 UTC  
**Status:** ✅ READY FOR TESTING  
**Next Action:** Change passwords, then test Sqoop import

---

**Questions? Check:**
- `CRITICAL_ISSUES_AND_FIXES.md` - Full incident report
- `Jenkinsfile_Sqoop_Optimized` - New Sqoop pipeline
- `Jenkinsfile_Spark_Fixed` - Fixed Spark pipeline
