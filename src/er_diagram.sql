-- ============================================================================
-- Entity Relationship Diagram (Text Version)
-- TfL Data Warehouse Star Schema
-- ============================================================================

/*

┌─────────────────────────────────────────────────────────────────────────┐
│                         TfL DATA WAREHOUSE SCHEMA                        │
│                              Star Schema Model                           │
└─────────────────────────────────────────────────────────────────────────┘


DIMENSION TABLES
================

┌────────────────────────┐
│     dim_networks       │
├────────────────────────┤
│ PK network_id          │
│    network_name        │
│    network_type        │
│    created_at          │
│    updated_at          │
└────────────┬───────────┘
             │
             │ 1
             │
             │ Many
┌────────────▼───────────┐
│     dim_stations       │
├────────────────────────┤
│ PK station_id          │
│    nlc_code            │
│    station_name        │
│ FK network_id          │
│    has_london_under..  │
│    has_elizabeth_line  │
│    has_overground      │
│    has_dlr             │
│    has_night_tube      │
│    is_active           │
│    created_at          │
│    updated_at          │
└────┬───────────────┬───┘
     │               │
     │ 1             │ 1
     │               │
     │ Many          │ Many
     │               │
┌────▼──────────┐    │    ┌─────────────────────┐
│  dim_lines    │    │    │     dim_date        │
├───────────────┤    │    ├─────────────────────┤
│ PK line_id    │    │    │ PK date_id          │
│    line_name  │    │    │    year             │
│    line_color │    │    │    quarter          │
│    is_night_s │    │    │    month            │
│    created_at │    │    │    is_annual        │
│    updated_at │    │    │    period_label     │
└────┬──────────┘    │    │    period_start     │
     │               │    │    period_end       │
     │ 1             │    │    created_at       │
     │               │    └─────────┬───────────┘
     │ Many          │              │
     │               │              │ 1
┌────▼───────────────▼────┐        │
│  fact_station_lines     │        │ Many
│  (Bridge Table)         │        │
├─────────────────────────┤        │
│ PK station_line_id      │        │
│ FK station_id           │        │
│ FK line_id              │        │
│    is_interchange       │        │
│    effective_from       │        │
│    effective_to         │        │
│    created_at           │        │
└─────────────────────────┘        │
                                   │
        ┌──────────────────────────┘
        │
        │
┌───────▼──────────────────────────┐
│  fact_passenger_entry_exit       │
│  (Main Fact Table)               │
├──────────────────────────────────┤
│ PK entry_exit_id (BIGSERIAL)     │
│ FK station_id                    │
│ FK date_id                       │
│    total_entry_exit              │
│    estimated_entries             │
│    estimated_exits               │
│    record_type                   │
│    data_source                   │
│    created_at                    │
└──────────────────────────────────┘


RELATIONSHIPS
=============

1. dim_networks (1) ──< (Many) dim_stations
   - One network has many stations

2. dim_stations (1) ──< (Many) fact_station_lines
   - One station can serve many lines

3. dim_lines (1) ──< (Many) fact_station_lines
   - One line serves many stations

4. dim_stations (1) ──< (Many) fact_passenger_entry_exit
   - One station has many passenger records over time

5. dim_date (1) ──< (Many) fact_passenger_entry_exit
   - One date period has many station records


CARDINALITY EXAMPLES
=====================

Station "King's Cross St. Pancras" has:
  - Multiple lines: Northern, Piccadilly, Victoria, Circle, Hammersmith & City, Metropolitan
  - Multiple date records: 2007, 2008, 2009, ... 2021
  - One network: London Underground

Line "Piccadilly" has:
  - Multiple stations: Cockfosters, Oakwood, ... Heathrow
  - Records in fact_station_lines for each station it serves

Date "2019" has:
  - Passenger records for all 436 stations
  - Each station's annual entry/exit count


INDEXES
=======

Performance indexes created on:
  - All primary keys (automatic)
  - All foreign keys
  - dim_stations.station_name
  - dim_lines.line_name
  - dim_date.year
  - Composite: (station_id, date_id), (date_id, station_id)


ANALYTICAL VIEWS
================

1. vw_station_summary
   - Complete station details with line aggregations

2. vw_annual_passenger_stats
   - Annual passenger statistics by station and line

3. vw_busiest_stations
   - Ranked stations by passenger volume per year

4. vw_line_stats
   - Line statistics: stations, interchanges, night service


DATA FLOW
=========

Raw TfL Data (Excel/CSV)
         │
         ▼
  data_modeling.py  ─────► Normalized CSV Files
         │                   │
         │                   ├── dim_networks.csv
         │                   ├── dim_lines.csv
         │                   ├── dim_stations.csv
         │                   ├── dim_date.csv
         │                   ├── fact_station_lines.csv
         │                   └── fact_passenger_entry_exit.csv
         │
         ▼
create_postgres_schema.sql ─► PostgreSQL Tables & Views
         │
         ▼
load_to_postgres.py ────────► Populated Data Warehouse
         │
         ▼
  Ready for Analytics!


QUERY PATTERNS
==============

1. Time Series Analysis:
   SELECT year, station, passengers
   FROM fact_passenger_entry_exit
   JOIN dim_date USING (date_id)
   JOIN dim_stations USING (station_id)

2. Geographic Analysis:
   SELECT network, line, COUNT(stations)
   FROM dim_stations
   JOIN fact_station_lines USING (station_id)
   JOIN dim_lines USING (line_id)
   GROUP BY network, line

3. Trend Analysis:
   WITH yearly AS (
     SELECT year, station_id, SUM(passengers) as total
     FROM fact_passenger_entry_exit
     JOIN dim_date USING (date_id)
     GROUP BY year, station_id
   )
   SELECT *, LAG(total) OVER (PARTITION BY station_id ORDER BY year)
   FROM yearly

*/

-- ============================================================================
-- End of ER Diagram
-- ============================================================================
