#!/bin/bash
# ============================================================================
# Create and initialize test database for local testing
# ============================================================================
# Usage: ./scripts/setup_test_db.sh
# This creates surypus_test database with all migrations and seed data

set -e

DB_NAME="surypus_test"
DB_USER="postgres"
DB_PASS=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  Surypus Test Database Setup"
echo "========================================="

# Check if PostgreSQL is available
if ! command -v psql &>/dev/null; then
	echo "PostgreSQL not found. Please install PostgreSQL first."
	exit 1
fi

# Create test database
echo "Creating test database..."
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || {
	echo "Could not create database. Is PostgreSQL running?"
	exit 1
}
echo "  Created $DB_NAME"

# Connect to database and run extensions first
echo "Setting up extensions..."
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"hstore\";"

# Run all migrations in numerical order
echo "Running migrations..."
MIGRATIONS_DIR="$PROJECT_DIR/sql/migrations"
for migration in "$MIGRATIONS_DIR"/V*.sql; do
	if [ -f "$migration" ]; then
		echo "  Applying $(basename "$migration")"
		PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$migration"
	fi
done

# Run seeds if directory exists
echo "Running seed data..."
if [ -d "$PROJECT_DIR/sql/seeds" ]; then
	for seed in "$PROJECT_DIR/sql/seeds"/*.sql; do
		if [ -f "$seed" ]; then
			echo "  Running $(basename "$seed")"
			PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f "$seed"
		fi
	done
fi

# Verify
echo "Verifying setup..."
TABLE_COUNT=$(PGPASSWORD="" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';" | tr -d ' ')
echo "  Tables in public schema: $TABLE_COUNT"

echo "========================================="
echo "  Test database ready!"
echo "  Connection string: postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME"
echo "  TEST_DB_DSN=postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME"
echo "========================================="