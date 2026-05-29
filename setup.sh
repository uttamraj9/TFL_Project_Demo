#!/bin/bash

echo "=========================================="
echo "TfL Data Warehouse - Setup Script"
echo "=========================================="

# Step 1: Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo ""
    echo "[1/4] Creating virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo ""
    echo "[1/4] Virtual environment already exists"
fi

# Step 2: Activate virtual environment and install dependencies
echo ""
echo "[2/4] Installing dependencies..."
source venv/bin/activate
pip install -r requirements.txt --quiet
echo "✓ Dependencies installed"

# Step 3: Generate normalized CSV files
echo ""
echo "[3/4] Generating normalized CSV files..."
python src/data_modeling.py
echo "✓ Normalized tables created"

# Step 4: Check PostgreSQL
echo ""
echo "[4/4] Checking PostgreSQL..."
if command -v psql &> /dev/null; then
    echo "✓ PostgreSQL is installed"

    # Check if PostgreSQL is running
    if pg_isready &> /dev/null; then
        echo "✓ PostgreSQL is running"
    else
        echo "⚠ PostgreSQL is not running"
        echo ""
        echo "Start PostgreSQL with:"
        echo "  macOS (Homebrew): brew services start postgresql"
        echo "  Linux (systemd):  sudo systemctl start postgresql"
        echo "  Manual:           pg_ctl -D /usr/local/var/postgres start"
    fi
else
    echo "⚠ PostgreSQL not found"
    echo ""
    echo "Install PostgreSQL:"
    echo "  macOS: brew install postgresql"
    echo "  Ubuntu: sudo apt-get install postgresql postgresql-contrib"
fi

echo ""
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Make sure PostgreSQL is running"
echo "2. Edit database credentials in src/load_to_postgres.py"
echo "3. Run: python src/load_to_postgres.py"
echo ""
echo "=========================================="
