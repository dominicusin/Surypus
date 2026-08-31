-- ============================================================================
-- Materialized Views for Common Queries
-- ============================================================================

-- Tenant summary MV (aggregates directly over event_store/aggregates tenant_id,
-- which are UUID; tenants.id is BIGINT so we do not join the tenants table here)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tenant_summary AS
SELECT
    a.tenant_id,
    COUNT(DISTINCT a.aggregate_id) as aggregates,
    COUNT(e.event_id) as total_events,
    MAX(e.created_at) as last_event,
    COUNT(DISTINCT CASE WHEN e.created_at > NOW() - INTERVAL '24 hours' THEN e.aggregate_id END) as active_24h
FROM aggregates a
LEFT JOIN event_store e ON e.tenant_id = a.tenant_id
GROUP BY a.tenant_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_tenant_summary ON mv_tenant_summary(tenant_id);

-- User activity MV
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_activity AS
SELECT 
    tenant_id,
    user_id,
    COUNT(*) as event_count,
    COUNT(DISTINCT aggregate_id) as aggregates_touched,
    MIN(created_at) as first_action,
    MAX(created_at) as last_action
FROM event_store
GROUP BY tenant_id, user_id;

CREATE INDEX IF NOT EXISTS idx_mv_user_activity ON mv_user_activity(tenant_id, user_id);

-- Daily aggregate health MV
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_aggregate_health AS
SELECT 
    a.aggregate_id,
    a.aggregate_type,
    a.tenant_id,
    a.current_version,
    a.event_count,
    COUNT(s.snapshot_id) as snapshot_count,
    MAX(e.created_at) as last_event,
    MAX(s.created_at) as last_snapshot,
    CASE 
        WHEN MAX(e.created_at) > NOW() - INTERVAL '1 hour' THEN 'healthy'
        WHEN MAX(e.created_at) > NOW() - INTERVAL '24 hours' THEN 'stale'
        ELSE 'neglected'
    END as health_status
FROM aggregates a
LEFT JOIN event_store e ON e.aggregate_id = a.aggregate_id
LEFT JOIN aggregate_snapshots s ON s.aggregate_id = a.aggregate_id
GROUP BY a.aggregate_id, a.aggregate_type, a.tenant_id, a.current_version, a.event_count;

CREATE INDEX IF NOT EXISTS idx_mv_aggregate_health ON mv_aggregate_health(tenant_id, health_status);

-- Refresh scheduler
CREATE TABLE IF NOT EXISTS mv_refresh_schedule (
    mv_name TEXT PRIMARY KEY,
    refresh_interval INTERVAL NOT NULL,
    last_refresh TIMESTAMP WITH TIME ZONE,
    next_refresh TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO mv_refresh_schedule (mv_name, refresh_interval, is_active)
VALUES 
    ('mv_tenant_summary', INTERVAL '1 hour', TRUE),
    ('mv_user_activity', INTERVAL '5 minutes', TRUE),
    ('mv_aggregate_health', INTERVAL '10 minutes', TRUE)
ON CONFLICT (mv_name) DO NOTHING;

CREATE OR REPLACE FUNCTION refresh_scheduled_mv() RETURNS VOID AS $$
DECLARE
    v_mv RECORD;
BEGIN
    FOR v_mv IN SELECT * FROM mv_refresh_schedule WHERE is_active = TRUE
    LOOP
        IF v_mv.next_refresh IS NULL OR v_mv.next_refresh <= NOW() THEN
            EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY %I', v_mv.mv_name);
            UPDATE mv_refresh_schedule SET 
                last_refresh = NOW(),
                next_refresh = NOW() + v_mv.refresh_interval
            WHERE mv_name = v_mv.mv_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;