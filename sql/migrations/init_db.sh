#!/bin/bash
# Initialization script for Surypus SQL refactoring
# Applies all migrations in order

set -e

echo "Starting Surypus SQL database initialization..."
echo "Applying migrations in order..."

# Create schema_migrations table if it doesn't exist
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(20) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT
);
"

# Apply all migrations in numerical order
for migration in sql/migrations/V*.sql; do
    # Extract version number
    version=$(basename "$migration" | sed 's/V//;s/.sql//')
    
    # Check if migration already applied
    applied=$(PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -t -c "SELECT 1 FROM schema_migrations WHERE version = '$version';" | xargs)
    
    if [ -z "$applied" ]; then
        echo "Applying migration: $version"
        PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -f "$migration"
        
        # Record migration
        description=$(head -5 "$migration" | grep -E "^--" | head -1 | sed 's/^-- //' | sed 's/ $//')
        if [ -z "$description" ]; then
            description="Migration $version"
        fi
        PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "INSERT INTO schema_migrations (version, description) VALUES ('$version', '$description') ON CONFLICT (version) DO NOTHING;"
    else
        echo "Skipping already applied migration: $version"
    fi
done

echo "All migrations applied successfully!"
echo "Running final validation..."

# Run a simple validation
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
SELECT 'Database Validation' as check, 
       COUNT(*) as table_count 
FROM pg_tables 
WHERE schemaname = 'public';
"

PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
SELECT 'Migration Count' as check, 
       COUNT(*) as applied_migrations 
FROM schema_migrations;
"

echo "Initialization complete!"
