-- ============================================================================
-- TfL Data Warehouse - PostgreSQL Schema
-- Star Schema with Fact and Dimension Tables
-- ============================================================================

-- Drop existing tables if they exist (in correct order due to FK constraints)
DROP TABLE IF EXISTS fact_passenger_entry_exit CASCADE;
DROP TABLE IF EXISTS fact_station_lines CASCADE;
DROP TABLE IF EXISTS dim_stations CASCADE;
DROP TABLE IF EXISTS dim_lines CASCADE;
DROP TABLE IF EXISTS dim_networks CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

-- dim_networks: Network types (Underground, Rail, etc.)
CREATE TABLE dim_networks (
    network_id INTEGER PRIMARY KEY,
    network_name VARCHAR(100) NOT NULL UNIQUE,
    network_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- dim_lines: Individual tube/rail lines
CREATE TABLE dim_lines (
    line_id INTEGER PRIMARY KEY,
    line_name VARCHAR(100) NOT NULL UNIQUE,
    line_color VARCHAR(7),  -- Hex color code
    is_night_service BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- dim_stations: Station master data
CREATE TABLE dim_stations (
    station_id INTEGER PRIMARY KEY,
    nlc_code VARCHAR(20),  -- Not unique as some stations have multiple service entries
    station_name VARCHAR(200) NOT NULL,
    network_id INTEGER,
    has_london_underground BOOLEAN DEFAULT FALSE,
    has_elizabeth_line BOOLEAN DEFAULT FALSE,
    has_overground BOOLEAN DEFAULT FALSE,
    has_dlr BOOLEAN DEFAULT FALSE,
    has_night_tube BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (network_id) REFERENCES dim_networks(network_id)
);

-- dim_date: Date/time dimension
CREATE TABLE dim_date (
    date_id INTEGER PRIMARY KEY,
    year INTEGER NOT NULL,
    quarter INTEGER,
    month INTEGER,
    is_annual BOOLEAN DEFAULT FALSE,
    period_label VARCHAR(50) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- BRIDGE TABLE (Many-to-Many relationship)
-- ============================================================================

-- fact_station_lines: Station-Line relationships
CREATE TABLE fact_station_lines (
    station_line_id INTEGER PRIMARY KEY,
    station_id INTEGER NOT NULL,
    line_id INTEGER NOT NULL,
    is_interchange BOOLEAN DEFAULT FALSE,
    effective_from DATE NOT NULL,
    effective_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES dim_stations(station_id),
    FOREIGN KEY (line_id) REFERENCES dim_lines(line_id),
    UNIQUE(station_id, line_id, effective_from)
);

-- ============================================================================
-- FACT TABLE
-- ============================================================================

-- fact_passenger_entry_exit: Main fact table for passenger movements
CREATE TABLE fact_passenger_entry_exit (
    entry_exit_id BIGSERIAL PRIMARY KEY,
    station_id INTEGER NOT NULL,
    date_id INTEGER NOT NULL,
    total_entry_exit BIGINT NOT NULL,
    estimated_entries BIGINT,
    estimated_exits BIGINT,
    record_type VARCHAR(20) NOT NULL,
    data_source VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES dim_stations(station_id),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    UNIQUE(station_id, date_id, record_type)
);

-- ============================================================================
-- INDEXES for Performance
-- ============================================================================

-- Dimension table indexes
CREATE INDEX idx_dim_stations_network ON dim_stations(network_id);
CREATE INDEX idx_dim_stations_name ON dim_stations(station_name);
CREATE INDEX idx_dim_lines_name ON dim_lines(line_name);
CREATE INDEX idx_dim_date_year ON dim_date(year);

-- Bridge table indexes
CREATE INDEX idx_fact_station_lines_station ON fact_station_lines(station_id);
CREATE INDEX idx_fact_station_lines_line ON fact_station_lines(line_id);
CREATE INDEX idx_fact_station_lines_dates ON fact_station_lines(effective_from, effective_to);

-- Fact table indexes
CREATE INDEX idx_fact_passenger_station ON fact_passenger_entry_exit(station_id);
CREATE INDEX idx_fact_passenger_date ON fact_passenger_entry_exit(date_id);
CREATE INDEX idx_fact_passenger_station_date ON fact_passenger_entry_exit(station_id, date_id);
CREATE INDEX idx_fact_passenger_date_station ON fact_passenger_entry_exit(date_id, station_id);

-- ============================================================================
-- VIEWS for Common Queries
-- ============================================================================

-- View: Station summary with all details
CREATE OR REPLACE VIEW vw_station_summary AS
SELECT
    s.station_id,
    s.station_name,
    s.nlc_code,
    n.network_name,
    n.network_type,
    s.has_london_underground,
    s.has_elizabeth_line,
    s.has_overground,
    s.has_dlr,
    s.has_night_tube,
    s.is_active,
    COUNT(DISTINCT sl.line_id) as number_of_lines,
    STRING_AGG(DISTINCT l.line_name, ', ' ORDER BY l.line_name) as lines_served
FROM dim_stations s
LEFT JOIN dim_networks n ON s.network_id = n.network_id
LEFT JOIN fact_station_lines sl ON s.station_id = sl.station_id AND sl.effective_to IS NULL
LEFT JOIN dim_lines l ON sl.line_id = l.line_id
GROUP BY s.station_id, s.station_name, s.nlc_code, n.network_name, n.network_type,
         s.has_london_underground, s.has_elizabeth_line, s.has_overground,
         s.has_dlr, s.has_night_tube, s.is_active;

-- View: Annual passenger statistics by station
CREATE OR REPLACE VIEW vw_annual_passenger_stats AS
SELECT
    d.year,
    s.station_name,
    l.line_name,
    SUM(f.total_entry_exit) as total_passengers,
    AVG(f.total_entry_exit) as avg_passengers,
    MAX(f.total_entry_exit) as max_passengers,
    MIN(f.total_entry_exit) as min_passengers
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
JOIN dim_date d ON f.date_id = d.date_id
LEFT JOIN fact_station_lines sl ON s.station_id = sl.station_id
LEFT JOIN dim_lines l ON sl.line_id = l.line_id
WHERE d.is_annual = TRUE
GROUP BY d.year, s.station_name, l.line_name;

-- View: Busiest stations by year
CREATE OR REPLACE VIEW vw_busiest_stations AS
SELECT
    d.year,
    s.station_name,
    SUM(f.total_entry_exit) as total_passengers,
    RANK() OVER (PARTITION BY d.year ORDER BY SUM(f.total_entry_exit) DESC) as rank_by_year
FROM fact_passenger_entry_exit f
JOIN dim_stations s ON f.station_id = s.station_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.is_annual = TRUE
GROUP BY d.year, s.station_name;

-- View: Line statistics
CREATE OR REPLACE VIEW vw_line_stats AS
SELECT
    l.line_name,
    l.line_color,
    COUNT(DISTINCT sl.station_id) as number_of_stations,
    COUNT(DISTINCT CASE WHEN s.has_night_tube THEN sl.station_id END) as night_tube_stations,
    COUNT(DISTINCT CASE WHEN sl.is_interchange THEN sl.station_id END) as interchange_stations
FROM dim_lines l
LEFT JOIN fact_station_lines sl ON l.line_id = sl.line_id
LEFT JOIN dim_stations s ON sl.station_id = s.station_id
GROUP BY l.line_name, l.line_color;

-- ============================================================================
-- COMMENTS for Documentation
-- ============================================================================

COMMENT ON TABLE dim_networks IS 'Dimension table for TfL network types';
COMMENT ON TABLE dim_lines IS 'Dimension table for individual tube/rail lines';
COMMENT ON TABLE dim_stations IS 'Dimension table for station master data';
COMMENT ON TABLE dim_date IS 'Date dimension table for time-based analysis';
COMMENT ON TABLE fact_station_lines IS 'Bridge table for many-to-many station-line relationships';
COMMENT ON TABLE fact_passenger_entry_exit IS 'Fact table containing passenger entry/exit statistics';

-- ============================================================================
-- Success Message
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TfL Data Warehouse Schema Created Successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Tables Created: 6';
    RAISE NOTICE 'Views Created: 4';
    RAISE NOTICE 'Indexes Created: 10';
    RAISE NOTICE '========================================';
END $$;
