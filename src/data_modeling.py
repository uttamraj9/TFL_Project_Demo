"""
TfL Data Modeling Script
Creates normalized tables with proper relationships and primary/foreign keys
"""

import pandas as pd
import numpy as np
from pathlib import Path
import re

# Setup paths
DATA_DIR = Path(__file__).parent.parent / 'Data'
OUTPUT_DIR = DATA_DIR / 'normalized'
OUTPUT_DIR.mkdir(exist_ok=True)

print("=" * 80)
print("TfL Data Modeling - Creating Normalized Tables")
print("=" * 80)

# Load the main station data
print("\n[1/7] Loading TfL stations data...")
df_stations = pd.read_csv(DATA_DIR / 'TfL_stations.csv')
print(f"   Loaded {len(df_stations)} stations")

# ============================================================================
# TABLE 1: dim_networks - Network dimension table
# ============================================================================
print("\n[2/7] Creating dim_networks table...")
networks = []
for idx, row in df_stations.iterrows():
    if pd.notna(row['NETWORK']):
        networks.append(row['NETWORK'])

unique_networks = sorted(set(networks))
dim_networks = pd.DataFrame({
    'network_id': range(1, len(unique_networks) + 1),
    'network_name': unique_networks,
    'network_type': ['Underground' if 'Underground' in n else 'Rail' for n in unique_networks]
})
dim_networks.to_csv(OUTPUT_DIR / 'dim_networks.csv', index=False)
print(f"   ✓ Created dim_networks: {len(dim_networks)} records")

# ============================================================================
# TABLE 2: dim_lines - Line dimension table
# ============================================================================
print("\n[3/7] Creating dim_lines table...")
all_lines = []
for idx, row in df_stations.iterrows():
    if pd.notna(row['LINES']):
        lines = [line.strip() for line in str(row['LINES']).split(',')]
        all_lines.extend(lines)

unique_lines = sorted(set(all_lines))
dim_lines = pd.DataFrame({
    'line_id': range(1, len(unique_lines) + 1),
    'line_name': unique_lines,
    'line_color': [
        '#B36305' if 'Bakerloo' in l else
        '#E32017' if 'Central' in l else
        '#FFD300' if 'Circle' in l else
        '#00782A' if 'District' in l else
        '#F3A9BB' if 'Hammersmith' in l else
        '#A0A5A9' if 'Jubilee' in l else
        '#9B0056' if 'Metropolitan' in l else
        '#000000' if 'Northern' in l else
        '#003688' if 'Piccadilly' in l else
        '#0098D4' if 'Victoria' in l else
        '#95CDBA' if 'Waterloo' in l else
        '#00AFAD' if 'Elizabeth' in l else
        '#EE7C0E' if 'Overground' in l else
        '#00A4A7' if 'DLR' in l else
        '#Gray'
        for l in unique_lines
    ],
    'is_night_service': ['Night' in l for l in unique_lines]
})
dim_lines.to_csv(OUTPUT_DIR / 'dim_lines.csv', index=False)
print(f"   ✓ Created dim_lines: {len(dim_lines)} records")

# ============================================================================
# TABLE 3: dim_stations - Station dimension table
# ============================================================================
print("\n[4/7] Creating dim_stations table...")

# Create network lookup
network_lookup = dict(zip(dim_networks['network_name'], dim_networks['network_id']))

dim_stations = pd.DataFrame({
    'station_id': range(1, len(df_stations) + 1),
    'nlc_code': df_stations['NLC'].astype(str).replace('nan', ''),
    'station_name': df_stations['Station'],
    'network_id': df_stations['NETWORK'].map(network_lookup).astype('Int64'),  # Nullable integer
    'has_london_underground': df_stations['London Underground'].map({'Yes': True, 'No': False, '': False}).fillna(False),
    'has_elizabeth_line': df_stations['Elizabeth Line'].map({'Yes': True, 'No': False, '': False}).fillna(False),
    'has_overground': df_stations['London Overground'].map({'Yes': True, 'No': False, '': False}).fillna(False),
    'has_dlr': df_stations['DLR'].map({'Yes': True, 'No': False, '': False}).fillna(False),
    'has_night_tube': df_stations['Night Tube?'].map({'Yes': True, 'No': False, '': False}).fillna(False),
    'is_active': True
})
# Write with proper handling of nulls
dim_stations.to_csv(OUTPUT_DIR / 'dim_stations.csv', index=False, na_rep='')
print(f"   ✓ Created dim_stations: {len(dim_stations)} records")

# ============================================================================
# TABLE 4: fact_station_lines - Station-Line bridge table (many-to-many)
# ============================================================================
print("\n[5/7] Creating fact_station_lines table...")

# Create line lookup
line_lookup = dict(zip(dim_lines['line_name'], dim_lines['line_id']))

station_lines = []
bridge_id = 1
for idx, row in df_stations.iterrows():
    station_id = idx + 1
    if pd.notna(row['LINES']):
        lines = [line.strip() for line in str(row['LINES']).split(',')]
        for line in lines:
            if line in line_lookup:
                station_lines.append({
                    'station_line_id': bridge_id,
                    'station_id': station_id,
                    'line_id': line_lookup[line],
                    'is_interchange': len(lines) > 1,
                    'effective_from': '2017-01-01',
                    'effective_to': None
                })
                bridge_id += 1

fact_station_lines = pd.DataFrame(station_lines)
fact_station_lines.to_csv(OUTPUT_DIR / 'fact_station_lines.csv', index=False, na_rep='')
print(f"   ✓ Created fact_station_lines: {len(fact_station_lines)} records")

# ============================================================================
# TABLE 5: dim_date - Date dimension table
# ============================================================================
print("\n[6/7] Creating dim_date table...")

years = range(2007, 2022)
date_records = []
date_id = 1

for year in years:
    date_records.append({
        'date_id': date_id,
        'year': year,
        'quarter': None,
        'month': None,
        'is_annual': True,
        'period_label': f'{year} Annual',
        'period_start': f'{year}-01-01',
        'period_end': f'{year}-12-31'
    })
    date_id += 1

dim_date = pd.DataFrame(date_records)
dim_date.to_csv(OUTPUT_DIR / 'dim_date.csv', index=False)
print(f"   ✓ Created dim_date: {len(dim_date)} records")

# ============================================================================
# TABLE 6: fact_passenger_entry_exit - Main fact table
# ============================================================================
print("\n[7/7] Creating fact_passenger_entry_exit table...")

# Extract year columns (En/Ex 2007, En/Ex 2008, etc.)
year_columns = [col for col in df_stations.columns if 'En/Ex' in col]

fact_records = []
fact_id = 1

for idx, row in df_stations.iterrows():
    station_id = idx + 1

    for year_col in year_columns:
        # Extract year from column name
        year_match = re.search(r'(\d{4})', year_col)
        if year_match:
            year = int(year_match.group(1))

            # Find corresponding date_id
            date_id = dim_date[dim_date['year'] == year]['date_id'].values[0]

            # Get passenger count
            passenger_count = row[year_col]

            if pd.notna(passenger_count) and passenger_count > 0:
                fact_records.append({
                    'entry_exit_id': fact_id,
                    'station_id': station_id,
                    'date_id': date_id,
                    'total_entry_exit': int(passenger_count),
                    'estimated_entries': int(passenger_count * 0.5),  # Approximation
                    'estimated_exits': int(passenger_count * 0.5),    # Approximation
                    'record_type': 'Annual',
                    'data_source': 'TfL Official'
                })
                fact_id += 1

fact_passenger_entry_exit = pd.DataFrame(fact_records)
fact_passenger_entry_exit.to_csv(OUTPUT_DIR / 'fact_passenger_entry_exit.csv', index=False)
print(f"   ✓ Created fact_passenger_entry_exit: {len(fact_passenger_entry_exit)} records")

# ============================================================================
# Summary and Data Dictionary
# ============================================================================
print("\n" + "=" * 80)
print("DATA MODEL SUMMARY")
print("=" * 80)

summary = f"""
Star Schema Created with the following tables:

DIMENSION TABLES:
1. dim_networks      : {len(dim_networks):,} records - Network types (Underground, Rail, etc.)
2. dim_lines         : {len(dim_lines):,} records - Individual lines with colors
3. dim_stations      : {len(dim_stations):,} records - Station master data
4. dim_date          : {len(dim_date):,} records - Date/time dimension (2007-2021)

BRIDGE TABLE:
5. fact_station_lines: {len(fact_station_lines):,} records - Many-to-many station-line relationships

FACT TABLE:
6. fact_passenger_entry_exit: {len(fact_passenger_entry_exit):,} records - Passenger entry/exit data

RELATIONSHIPS:
- dim_stations.network_id      → dim_networks.network_id (Many-to-One)
- fact_station_lines.station_id → dim_stations.station_id (Many-to-One)
- fact_station_lines.line_id    → dim_lines.line_id (Many-to-One)
- fact_passenger_entry_exit.station_id → dim_stations.station_id (Many-to-One)
- fact_passenger_entry_exit.date_id → dim_date.date_id (Many-to-One)

OUTPUT LOCATION: {OUTPUT_DIR}
"""

print(summary)

# Save data dictionary
data_dictionary = """
TfL DATA MODEL - DATA DICTIONARY
=================================

TABLE: dim_networks
-------------------
network_id      : INT (PK) - Unique network identifier
network_name    : VARCHAR - Name of the network (e.g., London Underground)
network_type    : VARCHAR - Type classification (Underground, Rail)

TABLE: dim_lines
----------------
line_id         : INT (PK) - Unique line identifier
line_name       : VARCHAR - Name of the line (e.g., Piccadilly, Central)
line_color      : VARCHAR - Official TfL line color hex code
is_night_service: BOOLEAN - Whether line offers night service

TABLE: dim_stations
-------------------
station_id              : INT (PK) - Unique station identifier
nlc_code                : VARCHAR - National Location Code
station_name            : VARCHAR - Station name
network_id              : INT (FK) - References dim_networks.network_id
has_london_underground  : BOOLEAN - Has Underground service
has_elizabeth_line      : BOOLEAN - Has Elizabeth line service
has_overground          : BOOLEAN - Has Overground service
has_dlr                 : BOOLEAN - Has DLR service
has_night_tube          : BOOLEAN - Has Night Tube service
is_active               : BOOLEAN - Station currently active

TABLE: fact_station_lines (Bridge Table)
-----------------------------------------
station_line_id : INT (PK) - Unique relationship identifier
station_id      : INT (FK) - References dim_stations.station_id
line_id         : INT (FK) - References dim_lines.line_id
is_interchange  : BOOLEAN - Station serves multiple lines
effective_from  : DATE - Relationship start date
effective_to    : DATE - Relationship end date (NULL if current)

TABLE: dim_date
---------------
date_id         : INT (PK) - Unique date identifier
year            : INT - Year (2007-2021)
quarter         : INT - Quarter (NULL for annual records)
month           : INT - Month (NULL for annual records)
is_annual       : BOOLEAN - Whether this is annual aggregate
period_label    : VARCHAR - Human-readable period description
period_start    : DATE - Period start date
period_end      : DATE - Period end date

TABLE: fact_passenger_entry_exit (Fact Table)
----------------------------------------------
entry_exit_id       : BIGINT (PK) - Unique transaction identifier
station_id          : INT (FK) - References dim_stations.station_id
date_id             : INT (FK) - References dim_date.date_id
total_entry_exit    : BIGINT - Total passenger movements
estimated_entries   : BIGINT - Estimated entries (50% of total)
estimated_exits     : BIGINT - Estimated exits (50% of total)
record_type         : VARCHAR - Type of record (Annual, Monthly, etc.)
data_source         : VARCHAR - Source of data
"""

with open(OUTPUT_DIR / 'DATA_DICTIONARY.txt', 'w') as f:
    f.write(data_dictionary)

print("\n✓ Data dictionary saved to: DATA_DICTIONARY.txt")
print("\n" + "=" * 80)
print("✓ Data modeling complete! All CSV files ready for PostgreSQL import.")
print("=" * 80)
