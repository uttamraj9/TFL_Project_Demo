# Multi-Environment Database Management Strategy

## 🌍 Environment Overview

You have **3 different environments** running on the same PostgreSQL instance:

```
PostgreSQL @ 13.42.152.118:5432
├── testdb (Development/Experimental)
│   ├── Portal Application (Active - ukartechsolution-portal)
│   ├── TfL Data Warehouse (Our new project)
│   └── Test/Demo data (various experiments)
│
├── staging_db (Staging Environment)
│   └── Portal Application (Pre-production testing)
│
└── production_db (Production Environment)
    └── Portal Application (Live users)
```

---

## 🎯 Current Situation

### Database: `testdb`
**Purpose:** Development & Experimental work
**Status:** Always running, mixed workloads
**Contains:**
- Portal application tables (15 tables) - **ACTIVE**
- TfL Data Warehouse (6 tables) - **NEW PROJECT (on-demand)**
- Test/experimental tables (18 tables) - Various

### Other Databases
- **`staging_db`** - Portal staging environment
- **`production_db`** - Portal production environment

---

## ✅ **RECOMMENDED SOLUTION: Schema-Based Isolation**

Since `testdb` is for **development and on-demand projects**, use PostgreSQL **schemas** for clean separation.

```
testdb Database Structure:
├── portal_app schema     (Portal development - always running)
├── tfl_warehouse schema  (TfL project - on-demand)
├── experiments schema    (Test tables, demos)
└── public schema         (Default, keep minimal)
```

---

## 🚀 Implementation Plan

### Phase 1: Create Schema Structure

```bash
python << 'EOF'
import psycopg2

conn = psycopg2.connect(
    host='13.42.152.118',
    port=5432,
    database='testdb',
    user='admin',
    password='admin123'
)

cursor = conn.cursor()

# Create schemas
schemas = ['portal_app', 'tfl_warehouse', 'experiments']
for schema in schemas:
    cursor.execute(f'CREATE SCHEMA IF NOT EXISTS {schema}')
    print(f'✓ Created schema: {schema}')

conn.commit()
cursor.close()
conn.close()

print('\n✓ Schema structure ready')
EOF
```

### Phase 2: Organize Tables by Purpose

```bash
python << 'EOF'
import psycopg2

conn = psycopg2.connect(
    host='13.42.152.118',
    port=5432,
    database='testdb',
    user='admin',
    password='admin123'
)

cursor = conn.cursor()

# TfL Data Warehouse tables
tfl_tables = [
    'dim_networks', 'dim_lines', 'dim_stations', 'dim_date',
    'fact_station_lines', 'fact_passenger_entry_exit'
]

# Portal application tables  
portal_tables = [
    'portal_users', 'learners', 'training_batches', 'batch_members',
    'enrollments', 'quiz_attempts', 'quiz_questions', 'quiz_results',
    'recordings_metadata', 'recording_watch_sessions', 'consultants',
    'smes', 'sme_remarks', 'training_processed', 'pending_msal_users'
]

# Experimental/test tables
experiment_tables = [
    'michael_test', 'michael_test1', 'test_write',
    'clp_processed', 'pmo_processed', 'training_processed',
    'cc_fraud_streaming_data', 'cc_fraud_trans'
]

# Move TfL tables
print('Moving TfL Data Warehouse tables...')
for table in tfl_tables:
    try:
        cursor.execute(f'ALTER TABLE {table} SET SCHEMA tfl_warehouse')
        print(f'  ✓ {table} → tfl_warehouse')
    except Exception as e:
        print(f'  ✗ {table}: {e}')

# Move Portal tables (optional - can keep in public)
# Uncomment if you want strict separation
# print('\nMoving Portal application tables...')
# for table in portal_tables:
#     try:
#         cursor.execute(f'ALTER TABLE {table} SET SCHEMA portal_app')
#         print(f'  ✓ {table} → portal_app')
#     except Exception as e:
#         print(f'  ✗ {table}: {e}')

# Move experimental tables
print('\nMoving experimental tables...')
for table in experiment_tables:
    try:
        cursor.execute(f'ALTER TABLE {table} SET SCHEMA experiments')
        print(f'  ✓ {table} → experiments')
    except Exception as e:
        print(f'  ✗ {table}: {e}')

# Move views
print('\nMoving TfL views...')
views = ['vw_station_summary', 'vw_annual_passenger_stats', 
         'vw_busiest_stations', 'vw_line_stats']
for view in views:
    try:
        cursor.execute(f'ALTER VIEW {view} SET SCHEMA tfl_warehouse')
        print(f'  ✓ {view} → tfl_warehouse')
    except Exception as e:
        print(f'  ✗ {view}: {e}')

conn.commit()
cursor.close()
conn.close()

print('\n✓ Schema organization complete')
EOF
```

### Phase 3: Update TfL Application Code

**Update `src/load_to_postgres.py`:**

```python
def connect_postgres():
    """Connect to PostgreSQL database"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        
        # Set search path to TfL schema
        cursor = conn.cursor()
        cursor.execute('SET search_path TO tfl_warehouse, public')
        cursor.close()
        
        print(f"✓ Connected to PostgreSQL: {DB_CONFIG['database']} (schema: tfl_warehouse)")
        return conn
    except psycopg2.Error as e:
        print(f"✗ Database connection failed: {e}")
        sys.exit(1)
```

**Update `src/create_postgres_schema.sql`:**

Add at the beginning:
```sql
-- Create TfL schema if not exists
CREATE SCHEMA IF NOT EXISTS tfl_warehouse;

-- Set search path for this session
SET search_path TO tfl_warehouse, public;

-- Rest of the DDL remains the same
-- All tables will be created in tfl_warehouse schema
```

---

## 📊 Final Database Structure

### testdb - Development Database

```
testdb
│
├── public schema (Default - keep minimal)
│   ├── portal_users (18 rows) ← Portal dev
│   ├── learners (2 rows)
│   ├── activity_logs (13K rows)
│   └── ... (other shared/utility tables)
│
├── portal_app schema (Optional - strict separation)
│   └── All portal tables if moved
│
├── tfl_warehouse schema ⭐ OUR PROJECT
│   ├── dim_networks (1 row)
│   ├── dim_lines (14 rows)
│   ├── dim_stations (436 rows)
│   ├── dim_date (15 rows)
│   ├── fact_station_lines (575 rows)
│   ├── fact_passenger_entry_exit (4,771 rows)
│   └── 4 analytical views
│
└── experiments schema
    ├── michael_test
    ├── test_write
    ├── cc_fraud_*
    └── ... (temporary/test tables)
```

---

## 🎮 Usage Patterns

### **For TfL Data Warehouse (On-Demand)**

**When Starting TfL Work:**
```sql
-- Connect with schema specified
\c testdb admin
SET search_path TO tfl_warehouse;

-- Now all queries use TfL schema
SELECT * FROM dim_stations;
SELECT * FROM vw_busiest_stations;
```

**Sqoop Export:**
```bash
sqoop import \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb?currentSchema=tfl_warehouse' \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /user/hadoop/tfl/dim_stations
```

**Python Access:**
```python
import psycopg2

conn = psycopg2.connect(
    host='13.42.152.118',
    port=5432,
    database='testdb',
    user='admin',
    password='admin123',
    options='-c search_path=tfl_warehouse'
)
```

### **For Portal Development (Always Running)**

Portal code continues working normally:
```sql
-- Portal queries stay in public schema
SELECT * FROM portal_users;
SELECT * FROM learners;
```

### **For Experiments**

```sql
-- Switch to experiments schema for test work
SET search_path TO experiments;

-- All test tables isolated
SELECT * FROM michael_test;
```

---

## 🧹 Maintenance & Cleanup

### Clean Up Temporary Tables (Safe to Drop)

```sql
-- Switch to experiments schema
SET search_path TO experiments;

-- Drop test tables
DROP TABLE IF EXISTS michael_test CASCADE;
DROP TABLE IF EXISTS michael_test1 CASCADE;
DROP TABLE IF EXISTS test_write CASCADE;

-- Clean up empty processed tables
DROP TABLE IF EXISTS clp_processed CASCADE;
DROP TABLE IF EXISTS pmo_processed CASCADE;
```

### Archive Old Data

```sql
-- Archive old watch history
CREATE TABLE experiments.watch_history_old AS
SELECT * FROM public.watch_history_incremental_load
WHERE created_at < '2024-01-01';

-- Delete archived records from main table
DELETE FROM public.watch_history_incremental_load
WHERE created_at < '2024-01-01';

-- Reclaim space
VACUUM FULL public.watch_history_incremental_load;
```

---

## 📈 Benefits of This Approach

### ✅ **For TfL Project (On-Demand)**
- Isolated in `tfl_warehouse` schema
- Start/stop without affecting portal
- Clean separation of concerns
- Easy to backup just TfL data
- Can drop entire schema when done

### ✅ **For Portal Development (Always Running)**
- No disruption to existing code
- Tables stay in familiar location
- Existing queries work unchanged
- Can move to `portal_app` schema later if needed

### ✅ **For Database Management**
- Clear organization by purpose
- Easy to identify table ownership
- Schema-level permissions possible
- Better performance monitoring
- Simplified backup strategy

---

## 🔄 Start/Stop TfL Warehouse

### When You Need TfL Data:

**Option 1: Keep schema, refresh data**
```bash
# Tables stay in tfl_warehouse schema
python src/load_to_postgres.py
```

**Option 2: Recreate schema from scratch**
```bash
# Drop entire TfL schema
psql -h 13.42.152.118 -U admin -d testdb -c "DROP SCHEMA IF EXISTS tfl_warehouse CASCADE"

# Recreate everything
python src/load_to_postgres.py
```

### When Done with TfL Work:

**Option 1: Keep data (recommended)**
```bash
# Just disconnect, schema stays for next time
# Data remains available but idle
```

**Option 2: Remove completely**
```bash
# Drop entire TfL schema to free space
psql -h 13.42.152.118 -U admin -d testdb \
  -c "DROP SCHEMA IF EXISTS tfl_warehouse CASCADE"
```

---

## 🔐 Permissions Strategy

### Create Read-Only User for TfL Data

```sql
-- Create read-only user for analytics/BI tools
CREATE USER tfl_analyst WITH PASSWORD 'tfl_readonly_123';

-- Grant connect
GRANT CONNECT ON DATABASE testdb TO tfl_analyst;

-- Grant usage on schema
GRANT USAGE ON SCHEMA tfl_warehouse TO tfl_analyst;

-- Grant select on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA tfl_warehouse TO tfl_analyst;

-- Auto-grant for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA tfl_warehouse
  GRANT SELECT ON TABLES TO tfl_analyst;
```

---

## 📊 Monitoring Queries

### Check Schema Sizes

```sql
SELECT 
    schemaname,
    COUNT(*) as tables,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))) as size
FROM pg_tables
WHERE schemaname IN ('public', 'portal_app', 'tfl_warehouse', 'experiments')
GROUP BY schemaname
ORDER BY SUM(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
```

### List Tables by Schema

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'tfl_warehouse'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Active Connections by Schema

```sql
SELECT 
    COALESCE(
        SUBSTRING(query FROM 'FROM\s+(\w+)\.'),
        'public'
    ) as schema_used,
    COUNT(*) as active_queries
FROM pg_stat_activity
WHERE datname = 'testdb' 
  AND state = 'active'
GROUP BY schema_used;
```

---

## 🚀 Backup & Restore Strategy

### Backup TfL Schema Only

```bash
# Export TfL data warehouse schema
pg_dump -h 13.42.152.118 -U admin -d testdb \
  --schema=tfl_warehouse \
  --file=tfl_warehouse_backup_$(date +%Y%m%d).sql

# Compressed backup
pg_dump -h 13.42.152.118 -U admin -d testdb \
  --schema=tfl_warehouse \
  --format=custom \
  --file=tfl_warehouse_backup_$(date +%Y%m%d).dump
```

### Restore TfL Schema

```bash
# Drop existing (if any)
psql -h 13.42.152.118 -U admin -d testdb \
  -c "DROP SCHEMA IF EXISTS tfl_warehouse CASCADE"

# Restore from backup
psql -h 13.42.152.118 -U admin -d testdb \
  -f tfl_warehouse_backup_20260530.sql

# Or from custom format
pg_restore -h 13.42.152.118 -U admin -d testdb \
  tfl_warehouse_backup_20260530.dump
```

---

## 📋 Quick Reference Card

### Connect to TfL Schema
```bash
psql -h 13.42.152.118 -U admin -d testdb -c "SET search_path TO tfl_warehouse"
```

### Query TfL Tables
```sql
-- With schema prefix
SELECT * FROM tfl_warehouse.dim_stations;

-- Or set search path once
SET search_path TO tfl_warehouse;
SELECT * FROM dim_stations;
```

### Check What's Running
```sql
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname IN ('portal_app', 'tfl_warehouse', 'experiments')
ORDER BY schemaname, tablename;
```

### Clean Everything
```sql
-- Remove TfL completely
DROP SCHEMA IF EXISTS tfl_warehouse CASCADE;

-- Remove experiments
DROP SCHEMA IF EXISTS experiments CASCADE;
```

---

## ✅ Final Recommendation

**Implement schema-based separation NOW:**

1. ✅ **Create schemas** (5 minutes)
2. ✅ **Move TfL tables** to `tfl_warehouse` (5 minutes)
3. ✅ **Move test tables** to `experiments` (5 minutes)
4. ✅ **Update TfL code** to use schema (10 minutes)
5. ✅ **Test queries** (5 minutes)

**Total Time:** 30 minutes

**Benefits:**
- Clean, organized database
- Portal unaffected
- TfL isolated and on-demand
- Easy to start/stop
- Professional setup

---

## 🎯 Next Steps

1. **Run Phase 1** - Create schemas
2. **Run Phase 2** - Move tables
3. **Run Phase 3** - Update code
4. **Test everything** - Verify both systems work
5. **Update GitHub** - Commit schema-aware code
6. **Document** - Update README with schema info

---

*Document Version: 1.0*
*Environment: Development (testdb)*
*Last Updated: 2026-05-30*
*Status: Implementation Ready*
