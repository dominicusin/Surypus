#!/bin/bash
# Surypus Optimized Database Initialization
# PostgreSQL 14+ with partitioning, materialized views, and performance optimizations

set -e

DB_NAME="${DB_NAME:-surypus}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5433}"

echo "=========================================="
echo "  Surypus Optimized DB Setup"
echo "=========================================="

# Check PostgreSQL version
PG_VERSION=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -t -c "SELECT current_setting('server_version_num')::int / 10000")
if [ "$PG_VERSION" -lt 14 ]; then
    echo "Warning: PostgreSQL 14+ recommended for partitioning"
fi

# Create database
echo "[1/5] Creating database..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tc \
    "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME"

# Run optimized schema
echo "[2/5] Running optimized schema..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f schema_optimized.sql

# Create additional indexes
echo "[3/5] Creating additional indexes..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_bill_date_status ON bill(dt, status);
CREATE INDEX IF NOT EXISTS idx_bill_line_goods_qtty ON bill_line(goods_id, qtty);
CREATE INDEX IF NOT EXISTS idx_stock_goods_price ON stock(goods_id, price);

-- Partial indexes for common filters
CREATE INDEX IF NOT EXISTS idx_goods_active_name ON goods(name) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_person_active_name ON person(name) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_location_active_name ON location(name) WHERE is_active = TRUE;

-- BRIN indexes for time-series (efficient for large tables)
CREATE INDEX IF NOT EXISTS idx_bill_dt_brin ON bill USING BRIN (dt);
CREATE INDEX IF NOT EXISTS idx_bill_line_dt_brin ON bill_line USING BRIN (bill_dt);
CREATE INDEX IF NOT EXISTS idx_trans_dt_brin ON trans USING BRIN (dt);
CREATE INDEX IF NOT EXISTS idx_audit_dt_brin ON audit_log USING BRIN (changed_at);

-- Function-based indexes
CREATE INDEX IF NOT EXISTS idx_goods_name_lower ON goods(LOWER(name));
CREATE INDEX IF NOT EXISTS idx_person_name_lower ON person(LOWER(name));

-- Refresh materialized views
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_stock;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_turnover;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_receivables;

-- Analyze for query planner
ANALYZE;
EOF

# Show statistics
echo "[4/5] Database statistics..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
SELECT 'Tables' AS type, COUNT(*) AS count FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Indexes', COUNT(*) FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'Partitions', COUNT(*) FROM pg_tables WHERE tablename LIKE '%_2024' OR tablename LIKE '%_2025' OR tablename LIKE '%_2026'
UNION ALL
SELECT 'Materialized Views', COUNT(*) FROM pg_matviews WHERE schemaname = 'public';
EOF

echo "[5/5] Setup complete!"
echo ""
echo "Optimizations applied:"
echo "  - Table partitioning by date (bill, bill_line, lot, gds_movement, trans, trans_line, audit_log)"
echo "  - BRIN indexes for time-series data"
echo "  - Partial indexes for common filters"
echo "  - Materialized views for reporting"
echo "  - Optimized data types"
echo "  - Generated columns for computed values"
echo "  - Automatic stock maintenance trigger"
echo ""
echo "Run 'psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME' to connect"