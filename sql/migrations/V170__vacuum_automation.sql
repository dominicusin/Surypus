-- ============================================================================
-- Vacuum Maintenance Automation
-- ============================================================================

-- Vacuum schedule configuration
CREATE TABLE IF NOT EXISTS vacuum_schedule (
    id SERIAL PRIMARY KEY,
    table_name TEXT UNIQUE NOT NULL,
    vacuum_enabled BOOLEAN DEFAULT TRUE,
    analyze_enabled BOOLEAN DEFAULT TRUE,
    vacuum_threshold INT DEFAULT 10000,
    analyze_threshold INT DEFAULT 1000,
    schedule_type TEXT CHECK (schedule_type IN ('manual', 'hourly', 'daily', 'weekly')),
    last_vacuum TIMESTAMP WITH TIME ZONE,
    last_analyze TIMESTAMP WITH TIME ZONE,
    next_scheduled TIMESTAMP WITH TIME ZONE
);

-- Default vacuum schedule
INSERT INTO vacuum_schedule (table_name, vacuum_enabled, analyze_enabled, schedule_type)
VALUES 
    ('event_store', TRUE, TRUE, 'daily'),
    ('aggregates', TRUE, TRUE, 'hourly'),
    ('event_outbox', TRUE, TRUE, 'hourly'),
    ('projection_audit', TRUE, TRUE, 'daily'),
    ('aggregate_snapshots', TRUE, TRUE, 'weekly')
ON CONFLICT (table_name) DO NOTHING;

-- Smart vacuum
CREATE OR REPLACE FUNCTION smart_vacuum(p_table_name TEXT) RETURNS VOID AS $$
DECLARE
    v_dead_tuples BIGINT;
    v_threshold INT;
BEGIN
    -- Get threshold
    SELECT vacuum_threshold INTO v_threshold
    FROM vacuum_schedule 
    WHERE table_name = p_table_name AND vacuum_enabled = TRUE;
    
    -- Check dead tuples
    SELECT n_dead_tup INTO v_dead_tuples
    FROM pg_stat_user_tables
    WHERE relname = p_table_name;
    
    IF v_dead_tuples > COALESCE(v_threshold, 10000) THEN
        EXECUTE format('VACUUM %I', p_table_name);
        UPDATE vacuum_schedule SET last_vacuum = NOW() WHERE table_name = p_table_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Smart analyze
CREATE OR REPLACE FUNCTION smart_analyze(p_table_name TEXT) RETURNS VOID AS $$
DECLARE
    v_seq_scan BIGINT;
    v_threshold INT;
BEGIN
    SELECT analyze_threshold INTO v_threshold
    FROM vacuum_schedule 
    WHERE table_name = p_table_name AND analyze_enabled = TRUE;
    
    SELECT seq_scan INTO v_seq_scan
    FROM pg_stat_user_tables
    WHERE relname = p_table_name;
    
    IF v_seq_scan > COALESCE(v_threshold, 1000) THEN
        EXECUTE format('ANALYZE %I', p_table_name);
        UPDATE vacuum_schedule SET last_analyze = NOW() WHERE table_name = p_table_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Full maintenance run
CREATE OR REPLACE FUNCTION run_maintenance() RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_table RECORD;
    v_vacuumed INT := 0;
    v_analyzed INT := 0;
BEGIN
    FOR v_table IN SELECT * FROM vacuum_schedule WHERE vacuum_enabled = TRUE OR analyze_enabled = TRUE
    LOOP
        IF v_table.vacuum_enabled THEN
            PERFORM smart_vacuum(v_table.table_name);
            v_vacuumed := v_vacuumed + 1;
        END IF;
        
        IF v_table.analyze_enabled THEN
            PERFORM smart_analyze(v_table.table_name);
            v_analyzed := v_analyzed + 1;
        END IF;
    END LOOP;
    
    v_result := jsonb_build_object(
        'tables_vacuumed', v_vacuumed,
        'tables_analyzed', v_analyzed,
        'completed_at', NOW()
    );
    
    PERFORM health_record('maintenance_run', 'healthy', v_vacuumed + v_analyzed, v_result::TEXT);
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Get maintenance recommendations
CREATE OR REPLACE FUNCTION maintenance_recommendations() RETURNS TABLE(
    table_name TEXT,
    recommendation TEXT,
    priority INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname || '.' || tablename as table_name,
        CASE 
            WHEN n_dead_tup > 100000 THEN 'VACUUM URGENT'
            WHEN n_dead_tup > 10000 THEN 'VACUUM recommended'
            WHEN seq_scan > 10000 THEN 'ANALYZE recommended'
            ELSE 'OK'
        END as recommendation,
        CASE 
            WHEN n_dead_tup > 100000 THEN 1
            WHEN n_dead_tup > 10000 THEN 2
            WHEN seq_scan > 10000 THEN 3
            ELSE 99
        END as priority
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
      AND (n_dead_tup > 10000 OR seq_scan > 10000)
    ORDER BY priority;
END;
$$ LANGUAGE plpgsql;