#!/bin/bash
# ============================================================================
# Surypus PostgreSQL Database Initialization
# ============================================================================

set -e

DB_NAME="surypus"
DB_USER="surypus"
DB_PASS="surypus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  Surypus PostgreSQL Setup"
echo "========================================="

# Check if PostgreSQL is available
if ! command -v psql &>/dev/null; then
	echo "PostgreSQL not found. Please install PostgreSQL first."
	exit 1
fi

# Create user and database
echo "Creating user and database..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true

# Connect to database and run extensions
echo "Setting up extensions..."
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"hstore\";"
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"jsonb\";"

# Run migrations in order
echo "Running migrations..."
MIGRATIONS_DIR="$PROJECT_DIR/sql/migrations"

for migration in "$MIGRATIONS_DIR"/V*.sql; do
	if [ -f "$migration" ]; then
		echo "  Applying $(basename "$migration")"
		sudo -u postgres psql -d $DB_NAME -f "$migration" 2>/dev/null || true
	fi
done

# Run procedures
echo "Running procedures..."
if [ -f "$PROJECT_DIR/sql/procedures.sql" ]; then
	sudo -u postgres psql -d $DB_NAME -f "$PROJECT_DIR/sql/procedures.sql" 2>/dev/null || true
fi

# Run seeds
echo "Running seed data..."
for seed in "$PROJECT_DIR/sql/seeds"/*.sql; do
	if [ -f "$seed" ]; then
		echo "  Running $(basename "$seed")"
		sudo -u postgres psql -d $DB_NAME -f "$seed" 2>/dev/null || true
	fi
done

echo "========================================="
echo "  Database initialized successfully"
echo "========================================="
