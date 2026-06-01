# TfL Data Warehouse & Portal Application - Database Coexistence Strategy

## 🔍 Current Situation Analysis

### Database: `testdb` @ 13.42.152.118:5432

**Total Tables: 39**

#### 1. TfL Data Warehouse (6 tables) - **OUR NEW TABLES**
```
dim_networks                    1 row
dim_lines                      14 rows
dim_stations                  436 rows
dim_date                       15 rows
fact_station_lines            575 rows
fact_passenger_entry_exit   4,771 rows
```

#### 2. Portal Application (15 tables) - **EXISTING APPLICATION**
```
portal_users                   18 rows
learners                        2 rows
training_batches                3 rows
batch_members                  20 rows
enrollments                     0 rows
quiz_attempts                 405 rows
quiz_questions                802 rows
quiz_results                    4 rows
recordings_metadata            11 rows
recording_watch_sessions        0 rows
consultants                     0 rows
smes                            2 rows
sme_remarks                     0 rows
training_processed              0 rows
pending_msal_users              2 rows
```

#### 3. Other Data (18 tables)
```
watch_history_incremental_load  105,000 rows
activity_logs                    13,886 rows
cc_fraud_trans                   35,000 rows
cc_fraud_streaming_data          10,000 rows
login_activity                    1,044 rows
... and 13 more tables
```

---

## ⚠️ Conflict Assessment

### Current Status: **✅ COEXISTING SAFELY**

**Good News:**
- ✅ No naming conflicts (dim_*/fact_* vs portal table names)
- ✅ No foreign key conflicts
- ✅ Tables are independent
- ✅ Both systems operational

**Concerns:**
- ⚠️ Single database for two different applications
- ⚠️ No logical separation (both in public schema)
- ⚠️ Backup/restore affects both systems
- ⚠️ Performance monitoring mixed

---

## 🎯 Recommended Solutions

### **Option 1: Use PostgreSQL Schemas (RECOMMENDED)**

Best for keeping both in same database with logical separation.

```sql
-- Create separate schemas
CREATE SCHEMA tfl_warehouse;
CREATE SCHEMA portal_app;

-- Move TfL tables to tfl_warehouse schema
ALTER TABLE dim_networks SET SCHEMA tfl_warehouse;
ALTER TABLE dim_lines SET SCHEMA tfl_warehouse;
ALTER TABLE dim_stations SET SCHEMA tfl_warehouse;
ALTER TABLE dim_date SET SCHEMA tfl_warehouse;
ALTER TABLE fact_station_lines SET SCHEMA tfl_warehouse;
ALTER TABLE fact_passenger_entry_exit SET SCHEMA tfl_warehouse;

-- Move Portal tables to portal_app schema
ALTER TABLE portal_users SET SCHEMA portal_app;
ALTER TABLE learners SET SCHEMA portal_app;
ALTER TABLE training_batches SET SCHEMA portal_app;
-- ... (move all 15 portal tables)

-- Update views to use schema-qualified names
ALTER VIEW vw_station_summary SET SCHEMA tfl_warehouse;
-- ... (move all views)
```

**Advantages:**
- ✅ Logical separation within same database
- ✅ No connection string changes needed
- ✅ Can set different permissions per schema
- ✅ Clean namespace organization
- ✅ Easy to backup individual schemas

**Access Pattern:**
```sql
-- TfL queries
SELECT * FROM tfl_warehouse.dim_stations;

-- Portal queries  
SELECT * FROM portal_app.portal_users;

-- Set default schema
SET search_path TO tfl_warehouse;
SELECT * FROM dim_stations;  -- Now works without prefix
```

---

### **Option 2: Separate Database (CLEANER)**

Create dedicated database for TfL warehouse.

```sql
-- Create new database
CREATE DATABASE tfl_datawarehouse;

-- Export TfL tables from testdb
pg_dump -h 13.42.152.118 -U admin -d testdb \
  -t dim_networks -t dim_lines -t dim_stations -t dim_date \
  -t fact_station_lines -t fact_passenger_entry_exit \
  --clean --if-exists > tfl_export.sql

-- Import to new database
psql -h 13.42.152.118 -U admin -d tfl_datawarehouse < tfl_export.sql

-- Drop TfL tables from testdb
DROP TABLE IF EXISTS fact_passenger_entry_exit CASCADE;
DROP TABLE IF EXISTS fact_station_lines CASCADE;
DROP TABLE IF EXISTS dim_stations CASCADE;
DROP TABLE IF EXISTS dim_lines CASCADE;
DROP TABLE IF EXISTS dim_networks CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
```

**Advantages:**
- ✅ Complete isolation
- ✅ Independent backups
- ✅ Independent performance tuning
- ✅ No naming conflict worries
- ✅ Easier to manage permissions

**Disadvantages:**
- ⚠️ Need to change connection strings in code
- ⚠️ Two databases to manage

**New Connection String:**
```python
# TfL Data Warehouse
DB_CONFIG = {
    'host': '13.42.152.118',
    'port': 5432,
    'database': 'tfl_datawarehouse',  # Changed
    'user': 'admin',
    'password': 'admin123'
}

# Portal stays on testdb
```

---

### **Option 3: Keep As-Is (ACCEPTABLE FOR NOW)**

Continue with both in same database/schema.

**When this works:**
- Small scale (both applications)
- Single team managing
- No regulatory separation needed
- Development/staging environment

**Best Practices if keeping as-is:**
1. **Document the sharing** (this file)
2. **Naming conventions:**
   - TfL tables: `dim_*`, `fact_*`
   - Portal tables: business domain names
   - Test tables: `test_*` prefix
3. **Regular cleanup:** Remove `michael_test`, `test_write`, etc.
4. **Monitoring:** Track table sizes and query patterns

---

## 📊 Comparison Matrix

| Criterion | Option 1: Schemas | Option 2: Separate DB | Option 3: As-Is |
|-----------|-------------------|----------------------|----------------|
| **Isolation** | Medium | High | Low |
| **Complexity** | Low | Medium | Very Low |
| **Performance** | Good | Excellent | Good |
| **Backup Strategy** | Schema-level | DB-level | Mixed |
| **Code Changes** | Minimal | Moderate | None |
| **Recommended For** | Shared infra | Production | Dev/Test |
| **Rating** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 🚀 Implementation Plan

### **Recommended: Option 1 (PostgreSQL Schemas)**

**Step 1: Create Schemas**
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
cursor.execute('CREATE SCHEMA IF NOT EXISTS tfl_warehouse')
cursor.execute('CREATE SCHEMA IF NOT EXISTS portal_app')

conn.commit()
print("✓ Schemas created")
cursor.close()
conn.close()
EOF
```

**Step 2: Move TfL Tables**
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

tfl_tables = [
    'dim_networks', 'dim_lines', 'dim_stations', 'dim_date',
    'fact_station_lines', 'fact_passenger_entry_exit'
]

for table in tfl_tables:
    cursor.execute(f'ALTER TABLE {table} SET SCHEMA tfl_warehouse')
    print(f'✓ Moved {table} to tfl_warehouse schema')

# Move views too
views = ['vw_station_summary', 'vw_annual_passenger_stats', 
         'vw_busiest_stations', 'vw_line_stats']
for view in views:
    try:
        cursor.execute(f'ALTER VIEW {view} SET SCHEMA tfl_warehouse')
        print(f'✓ Moved {view} to tfl_warehouse schema')
    except:
        pass

conn.commit()
cursor.close()
conn.close()
print("\n✓ All TfL tables moved to tfl_warehouse schema")
EOF
```

**Step 3: Update Application Code**

Update `src/load_to_postgres.py`:
```python
# Add search_path to queries
cursor.execute('SET search_path TO tfl_warehouse, public')

# Or use schema-qualified names
cursor.execute('SELECT COUNT(*) FROM tfl_warehouse.dim_stations')
```

Update `src/create_postgres_schema.sql`:
```sql
-- Add at the top of the file
CREATE SCHEMA IF NOT EXISTS tfl_warehouse;
SET search_path TO tfl_warehouse;

-- Rest of the DDL remains the same
```

**Step 4: Update Sqoop Commands**

```bash
# List tables in TfL schema
sqoop list-tables \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb?currentSchema=tfl_warehouse' \
  --username admin \
  --password admin123

# Import with schema
sqoop import \
  --connect 'jdbc:postgresql://13.42.152.118:5432/testdb?currentSchema=tfl_warehouse' \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /user/hadoop/tfl/dim_stations
```

**Step 5: Verify**
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

# Check TfL schema
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'tfl_warehouse'
    ORDER BY table_name
""")
print("TfL Warehouse Schema:")
for (table,) in cursor.fetchall():
    print(f"  ✓ {table}")

# Check Portal tables still in public
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name IN ('portal_users', 'learners', 'training_batches')
    ORDER BY table_name
""")
print("\nPortal Tables (public schema):")
for (table,) in cursor.fetchall():
    print(f"  ✓ {table}")

cursor.close()
conn.close()
EOF
```

---

## 🧹 Database Cleanup Recommendations

### Remove Test/Temporary Tables

```sql
-- These tables appear to be test data
DROP TABLE IF EXISTS michael_test CASCADE;
DROP TABLE IF EXISTS michael_test1 CASCADE;
DROP TABLE IF EXISTS test_write CASCADE;

-- Clean up processed tables if no longer needed
DROP TABLE IF EXISTS clp_processed CASCADE;
DROP TABLE IF EXISTS pmo_processed CASCADE;
DROP TABLE IF EXISTS training_processed CASCADE;

-- Verify empty tables before dropping
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns 
        WHERE table_name = t.table_name) as cols
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND (SELECT pg_total_relation_size(table_schema||'.'||table_name)) < 8192
ORDER BY table_name;
```

### Archive Old Data

```sql
-- Archive watch history older than 1 year
CREATE TABLE watch_history_archive AS
SELECT * FROM watch_history_incremental_load
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM watch_history_incremental_load
WHERE created_at < NOW() - INTERVAL '1 year';

-- Vacuum to reclaim space
VACUUM FULL watch_history_incremental_load;
```

---

## 📈 Monitoring & Maintenance

### Database Size by Schema
```sql
SELECT 
    schemaname,
    COUNT(*) as table_count,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))) as total_size
FROM pg_tables
WHERE schemaname IN ('public', 'tfl_warehouse', 'portal_app')
GROUP BY schemaname
ORDER BY SUM(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
```

### Top 10 Largest Tables
```sql
SELECT 
    schemaname || '.' || tablename as table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_total_relation_size(schemaname||'.'||tablename) as bytes
FROM pg_tables
WHERE schemaname IN ('public', 'tfl_warehouse', 'portal_app')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

### Connection Count by Application
```sql
SELECT 
    application_name,
    COUNT(*) as connections,
    string_agg(DISTINCT datname, ', ') as databases
FROM pg_stat_activity
WHERE datname = 'testdb'
GROUP BY application_name;
```

---

## 📝 Updated Documentation

After implementing schema separation, update these files:

1. **src/load_to_postgres.py** - Add schema support
2. **DEPLOYMENT_SUCCESS.md** - Update connection strings
3. **README.md** - Add schema information
4. **QUICKSTART.md** - Update queries with schema prefix

Example update for README:
```markdown
## Connecting to TfL Data Warehouse

### Using Schema-Qualified Names:
```sql
SELECT * FROM tfl_warehouse.dim_stations;
```

### Setting Search Path:
```sql
SET search_path TO tfl_warehouse;
SELECT * FROM dim_stations;  -- No prefix needed
```

---

## 🎓 Benefits of This Approach

✅ **No Disruption:** Portal application continues working normally
✅ **Clean Separation:** TfL tables isolated in their own schema  
✅ **Easy Management:** Can grant different permissions per schema
✅ **Better Organization:** Clear namespace ownership
✅ **Performance:** Can optimize each schema independently
✅ **Backup Strategy:** Schema-level backups possible
✅ **Documentation:** Clear which tables belong to which app

---

## 🚨 What NOT to Do

❌ Don't drop portal tables - they're in active use
❌ Don't modify portal table structure without checking app
❌ Don't create foreign keys between TfL and Portal tables
❌ Don't use generic table names (e.g., "data", "records")
❌ Don't ignore database maintenance (vacuum, analyze)

---

## 📞 Support & Questions

If you need to:
- **Move to separate database:** Follow Option 2 instructions
- **Keep shared database:** Implement Option 1 (schemas)
- **Understand portal app:** Check github.com/uttamraj9/ukartechsolution-portal
- **Question about specific table:** Query `information_schema` for details

---

## ✅ Final Recommendation

**Implement Option 1 (PostgreSQL Schemas) for:**
- Clean logical separation
- Minimal code changes
- Easy management
- Future flexibility

**Execute the implementation plan above** to move TfL tables to `tfl_warehouse` schema while keeping portal tables in their current location.

This provides the best balance of:
- ✅ Clean organization
- ✅ No application disruption  
- ✅ Easy maintenance
- ✅ Future scalability

---

*Document Version: 1.0*
*Last Updated: 2026-05-30*
*Status: Recommended Implementation Ready*
