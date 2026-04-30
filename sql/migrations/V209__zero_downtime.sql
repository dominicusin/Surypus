-- ============================================================================
-- Zero-Downtime Migration Support
-- ============================================================================

-- Migration state tracking
CREATE TABLE IF NOT EXISTS migration_state (
    migration_name TEXT PRIMARY KEY,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed', 'rolled_back')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    progress_percent INT DEFAULT 0,
    affected_rows BIGINT DEFAULT 0,
    error_message TEXT
);

-- Blue-green deployment tracking
CREATE TABLE IF NOT EXISTS deployment_environments (
    id SERIAL PRIMARY KEY,
    env_name TEXT UNIQUE NOT NULL,
    env_type TEXT CHECK (env_type IN ('blue', 'green', 'production')),
    is_active BOOLEAN DEFAULT FALSE,
    switchover_at TIMESTAMPTZ,
    health_check_url TEXT
);

-- Online schema migration
CREATE OR REPLACE FUNCTION online_migrate_column(
    p_table_name TEXT,
    p_column_name TEXT,
    p_new_type TEXT,
    p_default_value TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_migration_name TEXT;
BEGIN
    v_migration_name := p_table_name || '_' || p_column_name || '_migration';
    
    INSERT INTO migration_state (migration_name, status, started_at)
    VALUES (v_migration_name, 'running', NOW())
    ON CONFLICT (migration_name) DO UPDATE SET status = 'running';
    
    -- Add new column with default
    EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS %I %I', 
        p_table_name, p_column_name || '_new', p_new_type);
    
    IF p_default_value IS NOT NULL THEN
        EXECUTE format('UPDATE %I SET %I = %L', p_table_name, p_column_name || '_new', p_default_value);
    END IF;
    
    -- Backfill
    EXECUTE format('UPDATE %I SET %I = %I', 
        p_table_name, p_column_name || '_new', p_column_name);
    
    -- Swap columns (requires minimal lock)
    EXECUTE format('ALTER TABLE %I RENAME COLUMN %I TO %I_old', 
        p_table_name, p_column_name, p_column_name || '_old');
    EXECUTE format('ALTER TABLE %I RENAME COLUMN %I_new TO %I', 
        p_table_name, p_column_name, p_column_name);
    
    UPDATE migration_state SET status = 'completed', completed_at = NOW(), progress_percent = 100
    WHERE migration_name = v_migration_name;
    
EXCEPTION WHEN OTHERS THEN
    UPDATE migration_state SET status = 'failed', error_message = SQLERRM
    WHERE migration_name = v_migration_name;
    RAISE;
END;
$$ LANGUAGE plpgsql;