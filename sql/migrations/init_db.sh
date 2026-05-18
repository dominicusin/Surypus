#!/bin/bash
# Enhanced Initialization script for Surypus SQL refactoring
# Applies all migrations in order with proper error handling and idempotency

set -e

echo "Starting Surypus SQL database initialization..."
echo "Applying migrations in order..."

# Create schema version table (flyway-style)
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(20) PRIMARY KEY,
    description TEXT,
    type VARCHAR(20) DEFAULT 'SQL',
    script TEXT,
    installed_rank INTEGER,
    installed_on TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    execution_time INTEGER,
    success BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(10) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT
);
"

# Get count of already applied migrations
applied_count=$(PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -t -c "SELECT COUNT(*) FROM schema_version;" | xargs)

# Apply all migrations in numerical order
for migration in sql/migrations/V*.sql; do
    # Skip if not a file
    [ -f "$migration" ] || continue
    
    # Extract numeric version only (e.g., "000", "001", "100")
    version=$(basename "$migration" | sed 's/^V//;s/__.*//;s/\.sql$//')
    # Extract description from filename (after __, before .sql)
    description=$(basename "$migration" | sed 's/^V[0-9]*__//;s/\.sql$//' | tr '_' ' ')
    script_name=$(basename "$migration")
    
    # Check if migration already applied
    exists=$(PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -t -c "SELECT 1 FROM schema_version WHERE version = '$version';" | xargs)
    
    if [ -z "$exists" ]; then
        echo "Applying migration V$version: $description"
        
        # Measure execution time
        start_time=$(date +%s%N)
        
        if PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -f "$migration" 2>&1; then
            end_time=$(date +%s%N)
            exec_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
            
            # Increment rank
            new_rank=$((applied_count + 1))
            
            # Record in schema_version (flyway-style)
            PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
                INSERT INTO schema_version (version, description, type, script, installed_rank, execution_time, success)
                VALUES ('$version', '$description', 'SQL', '$script_name', $new_rank, $exec_time, TRUE)
                ON CONFLICT (version) DO UPDATE SET success = TRUE;
            "
            
            # Record in schema_migrations (legacy)
            PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
                INSERT INTO schema_migrations (version, description)
                VALUES ('$version', '$description')
                ON CONFLICT (version) DO NOTHING;
            "
            
            applied_count=$new_rank
            echo "  ✓ Applied successfully (${exec_time}ms)"
        else
            echo "  ✗ Failed to apply migration V$version"
            # Record failure
            PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
                INSERT INTO schema_version (version, description, type, script, installed_rank, success)
                VALUES ('$version', '$description', 'SQL', '$script_name', $applied_count, FALSE)
                ON CONFLICT (version) DO UPDATE SET success = FALSE;
            "
            exit 1
        fi
    else
        echo "Skipping already applied migration: V$version"
    fi
done

echo "All migrations applied successfully!"
echo ""
echo "Running final validation..."

# Run validation
echo ""
echo "Database Status:"
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
SELECT 'Tables Created' as metric, 
       COUNT(*) as count 
FROM pg_tables 
WHERE schemaname = 'public';
"

echo ""
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
SELECT 'Migrations Applied' as metric, 
       COUNT(*) as count 
FROM schema_version;
"

echo ""
PGPASSWORD=surypus_password psql -h localhost -U surypus -d surypus -c "
SELECT version, description, success 
FROM schema_version 
ORDER BY installed_rank;
"

echo ""
echo "Initialization complete!"