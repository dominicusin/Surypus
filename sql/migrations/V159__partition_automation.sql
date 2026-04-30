-- ============================================================================
-- Partition Maintenance Automation
-- ============================================================================

-- Partition metadata table
CREATE TABLE IF NOT EXISTS partition_metadata (
    id SERIAL PRIMARY KEY,
    parent_table TEXT NOT NULL,
    partition_name TEXT NOT NULL,
    partition_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    row_count BIGINT DEFAULT 0,
    size_bytes BIGINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(parent_table, partition_name)
);

-- Auto-create partition for new tenant
CREATE OR REPLACE FUNCTION auto_create_tenant_partition(
    p_tenant_id UUID
) RETURNS VOID AS $$
DECLARE
    v_partition_name TEXT;
    v_exists BOOLEAN;
BEGIN
    v_partition_name := 'event_store_' || replace(p_tenant_id::TEXT, '-', '_');
    
    SELECT EXISTS (
        SELECT 1 FROM pg_tables WHERE tablename = v_partition_name
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        EXECUTE format('CREATE TABLE %I PARTITION OF event_store FOR VALUES IN (%L)',
            v_partition_name, p_tenant_id);
        
        INSERT INTO partition_metadata (parent_table, partition_name, partition_value, is_active)
        VALUES ('event_store', v_partition_name, p_tenant_id::TEXT, TRUE)
        ON CONFLICT (parent_table, partition_name) DO NOTHING;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Partition statistics updater
CREATE OR REPLACE FUNCTION update_partition_stats() RETURNS VOID AS $$
DECLARE
    v_partition RECORD;
BEGIN
    FOR v_partition IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename LIKE 'event_store_%'
          AND tablename <> 'event_store'
          AND tablename <> 'event_store_default'
    LOOP
        UPDATE partition_metadata SET
            row_count = (SELECT COUNT(*) FROM pg_stat_user_tables WHERE relname = v_partition.tablename),
            size_bytes = (SELECT pg_total_relation_size(v_partition.tablename)),
            updated_at = NOW()
        WHERE partition_name = v_partition.tablename;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Archive old partitions
CREATE OR REPLACE FUNCTION archive_old_partitions(
    p_before_date DATE,
    p_archive_schema TEXT DEFAULT 'archive'
) RETURNS INT AS $$
DECLARE
    v_partition TEXT;
    v_count INT := 0;
BEGIN
    CREATE SCHEMA IF NOT EXISTS archive;
    
    FOR v_partition IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename LIKE 'event_store_%'
          AND tablename <> 'event_store_default'
    LOOP
        IF EXISTS (
            SELECT 1 FROM partition_metadata 
            WHERE partition_name = v_partition 
              AND row_count = 0
        ) THEN
            EXECUTE format('ALTER TABLE %I SET LOGGED', v_partition);
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Partition health check
CREATE OR REPLACE FUNCTION check_partition_health() RETURNS TABLE(
    partition_name TEXT,
    status TEXT,
    row_count BIGINT,
    size_mb TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.partition_name,
        CASE 
            WHEN pm.row_count > 10000000 THEN 'large'
            WHEN pm.row_count > 1000000 THEN 'medium'
            ELSE 'normal'
        END as status,
        pm.row_count,
        pg_size_pretty(pm.size_bytes)::TEXT as size_mb
    FROM partition_metadata pm
    WHERE pm.is_active = TRUE
    ORDER BY pm.row_count DESC;
END;
$$ LANGUAGE plpgsql;