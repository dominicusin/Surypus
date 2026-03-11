#!/bin/bash
# ============================================================================
# Surypus PostgreSQL Database Initialization
# ============================================================================

set -e

DB_NAME="surypus"
DB_USER="surypus"
DB_PASS="surypus"

echo "========================================="
echo "  Surypus PostgreSQL Setup"
echo "========================================="

# Check if PostgreSQL is available
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL not found. Please install PostgreSQL first."
    exit 1
fi

# Create user and database
echo "Creating user and database..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true

# Connect to database and run schema
echo "Running schema..."
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"hstore\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"jsonb\";"

# Run main schema
sudo -u postgres psql -d $DB_NAME -f config/database_schema.sql

# Run additional schemas
for f in config/schema_*.sql; do
    echo "  Running $f"
    sudo -u postgres psql -d $DB_NAME -f "$f" 2>/dev/null || true
done

# Create test data
echo "Creating test data..."
sudo -u postgres psql -d $DB_NAME -c "
INSERT INTO persons.person (code, name, inn, kpp, person_kind, status, credit_limit, discount) VALUES 
  ('001', 'Company A', '1234567890', '123456789', 1, 0, 100000, 5),
  ('002', 'Company B', '0987654321', '987654321', 1, 0, 50000, 3),
  ('003', 'Supplier X', '1111111111', '111111111', 2, 0, 200000, 10)
ON CONFLICT (code) DO NOTHING;

INSERT INTO goods.goods (code, name, barcode, unit_id, goods_type, tax_id, status, min_stock) VALUES
  ('001', 'Product A', '1234567890123', 1, 1, 1, 0, 10),
  ('002', 'Product B', '1234567890124', 1, 1, 1, 0, 5),
  ('003', 'Product C', '1234567890125', 1, 2, 1, 0, 20)
ON CONFLICT (code) DO NOTHING;

INSERT INTO warehouse.location (code, name, location_type, status, capacity) VALUES
  ('WH-01', 'Main Warehouse', 1, 0, 1000),
  ('WH-02', 'Second Warehouse', 1, 0, 500),
  ('SHOP-01', 'Retail Shop', 2, 0, 100)
ON CONFLICT (code) DO NOTHING;
"

echo ""
echo "========================================="
echo "  Database Ready!"
echo "========================================="
echo "Connection string: postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME"
echo ""
echo "Tables created:"
sudo -u postgres psql -d $DB_NAME -c "\dt" | grep -v "rows)" | tail -n +3
