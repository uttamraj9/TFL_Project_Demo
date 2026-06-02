# TfL Data Warehouse - Sqoop Import Scripts

## 📁 Scripts Overview

This directory contains Sqoop scripts for importing TfL data from PostgreSQL to HDFS.

### Available Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `import_all_tables.sh` | Import all 6 tables to HDFS | `./import_all_tables.sh` |
| `import_single_table.sh` | Import one table at a time | `./import_single_table.sh <table_name>` |
| `import_as_parquet.sh` | Import as Parquet format | `./import_as_parquet.sh` |
| `import_with_query.sh` | Import with custom SQL query | `./import_with_query.sh` |

---

## 🚀 Quick Start

### 1. Import All Tables (Recommended)

```bash
cd src/sqoop
chmod +x *.sh
./import_all_tables.sh
```

This will import all 6 tables to `/tmp/uttam/tfl_data/`

### 2. Import Single Table

```bash
./import_single_table.sh dim_stations 1
```

### 3. Import as Parquet (Better Performance)

```bash
./import_as_parquet.sh
```

### 4. Import with Custom Query

```bash
./import_with_query.sh
```

---

## ⚙️ Configuration

All scripts use these connection settings:

```bash
Database: testdb @ 13.42.152.118:5432
Username: admin
Password: admin123
Target:   /tmp/uttam/tfl_data/
```

To change target directory, edit the `TARGET_DIR` variable in each script:

```bash
export TARGET_DIR="/tmp/uttam/tfl_data"
```

---

## 📊 Tables to Import

### Dimension Tables
- `dim_networks` (1 record) - Network types
- `dim_lines` (14 records) - Tube/rail lines
- `dim_stations` (436 records) - Station master data
- `dim_date` (15 records) - Time dimension

### Bridge Table
- `fact_station_lines` (575 records) - Station-line relationships

### Fact Table
- `fact_passenger_entry_exit` (4,771 records) - Passenger statistics

**Total Records:** 5,812

---

## 🔍 Verification Commands

After import, verify data in HDFS:

```bash
# List all imported tables
hdfs dfs -ls /tmp/uttam/tfl_data

# Check specific table
hdfs dfs -ls /tmp/uttam/tfl_data/dim_stations

# View first 10 rows
hdfs dfs -cat /tmp/uttam/tfl_data/dim_stations/part-m-00000 | head -10

# Count rows
hdfs dfs -cat /tmp/uttam/tfl_data/dim_stations/part-* | wc -l

# Check file sizes
hdfs dfs -du -h /tmp/uttam/tfl_data
```

---

## 📦 Output Structure

```
/tmp/uttam/tfl_data/
├── dim_networks/
│   └── part-m-00000
├── dim_lines/
│   └── part-m-00000
├── dim_stations/
│   └── part-m-00000
├── dim_date/
│   └── part-m-00000
├── fact_station_lines/
│   └── part-m-00000
└── fact_passenger_entry_exit/
    ├── part-m-00000
    └── part-m-00001 (if using 2+ mappers)
```

---

## 🎯 Import Options

### Basic Import (Text Format)

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /tmp/uttam/tfl_data/dim_stations \
  -m 1
```

### Parquet Format (Recommended)

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /tmp/uttam/tfl_data_parquet/dim_stations \
  --as-parquetfile \
  --compression-codec snappy \
  -m 1
```

**Benefits of Parquet:**
- 50-80% smaller files
- Faster queries (columnar)
- Better compression
- Hive/Spark compatible

### Custom Query Import

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --query "SELECT s.station_name, d.year, f.total_entry_exit FROM fact_passenger_entry_exit f JOIN dim_stations s ON f.station_id = s.station_id JOIN dim_date d ON f.date_id = d.date_id WHERE d.year = 2019 AND \$CONDITIONS" \
  --split-by f.entry_exit_id \
  --target-dir /tmp/uttam/tfl_data_custom/passenger_2019 \
  -m 2
```

**Note:** `$CONDITIONS` is required by Sqoop for splitting data across mappers.

---

## ⚡ Performance Tuning

### Mapper Count

- **Small tables (< 1000 rows):** Use `-m 1`
  ```bash
  ./import_single_table.sh dim_networks 1
  ```

- **Medium tables (1000-10000 rows):** Use `-m 2`
  ```bash
  ./import_single_table.sh dim_stations 2
  ```

- **Large tables (> 10000 rows):** Use `-m 4` or more
  ```bash
  ./import_single_table.sh fact_passenger_entry_exit 4
  ```

### Direct Mode (Faster)

For PostgreSQL, use direct mode:

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table dim_stations \
  --target-dir /tmp/uttam/tfl_data/dim_stations \
  --direct \
  -m 1
```

**Note:** Requires `pg_dump` on the Sqoop client machine.

---

## 🔄 Incremental Imports

### Append Mode (New Records Only)

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table fact_passenger_entry_exit \
  --target-dir /tmp/uttam/tfl_data/fact_passenger_entry_exit \
  --incremental append \
  --check-column entry_exit_id \
  --last-value 4771 \
  -m 2
```

### Last Modified Mode

```bash
sqoop import \
  --connect "jdbc:postgresql://13.42.152.118:5432/testdb" \
  --username admin \
  --password admin123 \
  --table fact_passenger_entry_exit \
  --target-dir /tmp/uttam/tfl_data/fact_passenger_entry_exit \
  --incremental lastmodified \
  --check-column updated_at \
  --last-value "2026-05-30 00:00:00" \
  --merge-key entry_exit_id \
  -m 2
```

---

## 🐛 Troubleshooting

### Issue: "No such table"

**Solution:** Check table name is correct and exists:

```bash
psql -h 13.42.152.118 -U admin -d testdb -c "\dt"
```

### Issue: "JDBC driver not found"

**Solution:** Ensure PostgreSQL JDBC driver is in Sqoop classpath:

```bash
cp postgresql-42.7.1.jar $SQOOP_HOME/lib/
# or
cp postgresql-42.7.1.jar /usr/lib/sqoop/lib/
```

### Issue: "Permission denied on HDFS"

**Solution:** Check HDFS permissions:

```bash
hdfs dfs -mkdir -p /tmp/uttam/tfl_data
hdfs dfs -chmod 755 /tmp/uttam/tfl_data
```

### Issue: "Connection refused"

**Solution:** Test database connectivity:

```bash
psql -h 13.42.152.118 -p 5432 -U admin -d testdb -c "SELECT 1"
```

---

## 📝 Best Practices

1. ✅ **Test with small table first** (dim_networks)
2. ✅ **Use Parquet for large datasets** (better compression)
3. ✅ **Set appropriate mapper count** (based on data size)
4. ✅ **Use `--delete-target-dir`** (clean imports)
5. ✅ **Verify data after import** (row counts, sample data)
6. ✅ **Monitor HDFS space** before large imports
7. ✅ **Use custom queries** for filtered data
8. ✅ **Schedule incremental imports** for updates

---

## 📚 Additional Resources

- [Apache Sqoop Documentation](https://sqoop.apache.org/docs/)
- [PostgreSQL JDBC Driver](https://jdbc.postgresql.org/download/)
- [Parquet Format Guide](https://parquet.apache.org/docs/)
- [HDFS Commands Reference](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HDFSCommands.html)

---

## 📞 Support

For issues or questions:
1. Check this README
2. Verify database connectivity
3. Check HDFS permissions
4. Review Sqoop logs

**Project Repository:** https://github.com/uttamraj9/TFL_Project_Demo

---

*Last Updated: June 2, 2026*
