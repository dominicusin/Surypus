-- ============================================================================
-- Data Archival Policies
-- ============================================================================

-- Archive configuration
CREATE TABLE IF NOT EXISTS archive_config (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    archive_table TEXT NOT NULL,
    partition_key TEXT,
    retention_days INT NOT NULL,
    compression_type TEXT DEFAULT 'pg_default',
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(table_name)
);

-- Default archive configs
INSERT INTO archive_config (table_name, archive_table, partition_key, retention_days)
VALUES 
    ('event_store', 'event_store_archive', 'created_at', 2555),  -- 7 years
    ('projection_audit', 'projection_audit_archive', 'created_at', 365),  -- 1 year
    ('api_request_log', 'api_request_log_archive', 'created_at', 730)  -- 2 years
ON CONFLICT (table_name) DO NOTHING;

-- Archive table creation helper
CREATE OR REPLACE FUNCTION create_archive_table(
    p_source_table TEXT,
    p_archive_table TEXT
) RETURNS VOID AS $$
BEGIN
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I (LIKE %I INCLUDING ALL)', 
        p_archive_table, p_source_table);
    
    EXECUTE format('ALTER TABLE %I ADD PRIMARY KEY (SELECT pk FROM information_schema.table_constraints WHERE table_name = ''%I'' AND constraint_type = ''PRIMARY KEY'')', 
        p_archive_table, p_source_table);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Archive table creation skipped: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Archive execution
CREATE OR REPLACE FUNCTION execute_archive(
    p_table_name TEXT,
    p_batch_size INT DEFAULT 10000
) RETURNS INT AS $$
DECLARE
    v_config RECORD;
    v_archived INT := 0;
    v_sql TEXT;
BEGIN
    SELECT * INTO v_config FROM archive_config 
    WHERE table_name = p_table_name AND is_active = TRUE;
    
    IF v_config IS NULL THEN
        RETURN 0;
    END IF;
    
    -- Ensure archive table exists
    PERFORM create_archive_table(p_table_name, v_config.archive_table);
    
    -- Archive old data
    v_sql := format('
        WITH archived AS (
            DELETE FROM %I
            WHERE created_at < NOW() - (%%L || '' days'')::INTERVAL
            LIMIT %L
            RETURNING *
        )
        INSERT INTO %I SELECT * FROM archived',
        p_table_name, v_config.retention_days, p_batch_size, v_config.archive_table);
    
    EXECUTE v_sql;
    GET DIAGNOSTICS v_archived = ROW_COUNT;
    
    RETURN v_archived;
END;
$$ LANGUAGE plpgsql;

-- Scheduled archival
CREATE OR REPLACE FUNCTION run_scheduled_archive() RETURNS VOID AS $$
DECLARE
    v_config RECORD;
BEGIN
    FOR v_config IN SELECT * FROM archive_config WHERE is_active = TRUE
    LOOP
        PERFORM execute_archive(v_config.table_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;