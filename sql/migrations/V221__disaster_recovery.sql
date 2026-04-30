-- ============================================================================
-- Advanced Backup & Disaster Recovery
-- ============================================================================

-- Backup configuration
CREATE TABLE IF NOT EXISTS backup_configs (
    id SERIAL PRIMARY KEY,
    backup_type TEXT CHECK (backup_type IN ('full', 'incremental', 'snapshot')),
    schedule TEXT NOT NULL,
    retention_days INT DEFAULT 30,
    compression BOOLEAN DEFAULT TRUE,
    encryption_enabled BOOLEAN DEFAULT TRUE,
    destination TEXT CHECK (destination IN ('local', 's3', 'gcs', 'azure')),
    is_active BOOLEAN DEFAULT TRUE
);

-- Backup execution log
CREATE TABLE IF NOT EXISTS backup_executions (
    id BIGSERIAL PRIMARY KEY,
    backup_id INT REFERENCES backup_configs(id),
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    size_bytes BIGINT,
    file_path TEXT
);

-- Disaster recovery plan
CREATE TABLE IF NOT EXISTS disaster_recovery_plans (
    id SERIAL PRIMARY KEY,
    plan_name TEXT UNIQUE NOT NULL,
    rto_minutes INT DEFAULT 60,  -- Recovery Time Objective
    rpo_minutes INT DEFAULT 15,  -- Recovery Point Objective
    steps JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create backup config
INSERT INTO backup_configs (backup_type, schedule, retention_days, destination)
VALUES 
    ('full', '0 2 * * *', 30, 's3'),
    ('incremental', '0 * * * *', 7, 's3'),
    ('snapshot', '*/15 * * * *', 3, 'local')
ON CONFLICT DO NOTHING;

-- Point-in-time recovery
CREATE OR REPLACE FUNCTION point_in_time_recovery(
    p_target_timestamp TIMESTAMPTZ,
    p_aggregate_ids UUID[]
) RETURNS INT AS $$
DECLARE
    v_restored INT := 0;
    v_aggregate UUID;
BEGIN
    FOREACH v_aggregate IN ARRAY p_aggregate_ids
    LOOP
        -- Restore events up to timestamp
        INSERT INTO event_store (aggregate_id, aggregate_type, event_type, event_data, tenant_id, created_at)
        SELECT aggregate_id, aggregate_type, event_type, event_data, tenant_id, created_at
        FROM temporal_snapshots
        WHERE entity_type = 'aggregate' AND entity_id = v_aggregate
          AND valid_from <= p_target_timestamp;
        
        v_restored := v_restored + 1;
    END LOOP;
    
    RETURN v_restored;
END;
$$ LANGUAGE plpgsql;