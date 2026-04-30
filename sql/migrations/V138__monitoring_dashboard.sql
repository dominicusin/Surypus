-- Monitoring dashboard for system health
CREATE OR REPLACE VIEW v_dashboard AS
SELECT 
    -- Event store stats
    (SELECT COUNT(*) FROM event_store) as total_events,
    (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
    -- Snapshot stats
    (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
    -- Outbox stats
    (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
    -- DLQ stats
    (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as unresolved_dlq,
    -- Projection stats
    (SELECT COUNT(*) FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as last_hour_projections,
    (SELECT COUNT(*) FROM projection_audit WHERE status = 'failure' AND created_at > NOW() - INTERVAL '1 hour') as failed_projections,
    -- Health
    (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;

-- Active session stats
CREATE OR REPLACE VIEW v_active_sessions AS
SELECT 
    usename as username,
    COUNT(*) as session_count,
    MAX(backend_start) as latest_session
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY usename;