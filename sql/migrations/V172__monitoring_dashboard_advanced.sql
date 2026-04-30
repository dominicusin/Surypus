-- ============================================================================
-- Advanced Monitoring Dashboard
-- ============================================================================

-- Dashboard metrics view
CREATE OR REPLACE VIEW v_dashboard_advanced AS
SELECT 
    -- Events
    (SELECT COUNT(*) FROM event_store) as total_events,
    (SELECT COUNT(*) FROM event_store WHERE created_at > NOW() - INTERVAL '1 hour') as events_1h,
    (SELECT COUNT(*) FROM event_store WHERE created_at > NOW() - INTERVAL '24 hours') as events_24h,
    
    -- Aggregates
    (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
    (SELECT COUNT(*) FROM aggregates) as aggregate_count,
    
    -- Projections
    (SELECT COUNT(*) FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as projections_1h,
    (SELECT AVG(duration_ms)::INT FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as avg_projection_ms,
    (SELECT COUNT(*) FROM projection_audit WHERE status = 'failure' AND created_at > NOW() - INTERVAL '1 hour') as failed_projections,
    
    -- Outbox
    (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
    (SELECT COUNT(*) FROM event_outbox WHERE created_at < NOW() - INTERVAL '1 hour' AND published = FALSE) as stuck_outbox,
    
    -- DLQ
    (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as dlq_pending,
    (SELECT MAX(retry_count) FROM event_dlq WHERE resolved = FALSE) as max_dlq_retries,
    
    -- Performance
    (SELECT AVG(duration_ms) FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as avg_projection_duration,
    (SELECT MAX(duration_ms) FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as max_projection_duration,
    
    -- Cache
    (SELECT COUNT(*) FROM cache_tiers) as cache_keys,
    (SELECT SUM(hits) FROM cache_tiers) as cache_hits,
    
    -- Connections
    (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = current_database()) as active_connections,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle' AND datname = current_database()) as idle_connections,
    
    -- Health
    NOW() as current_time;

-- Real-time alerts view
CREATE OR REPLACE VIEW v_realtime_alerts AS
SELECT 
    'high_dlq' as alert_type,
    'Dead Letter Queue backlog' as message,
    'critical' as severity
WHERE (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) > 100

UNION ALL

SELECT 
    'stuck_outbox' as alert_type,
    'Outbox not processing' as message,
    'critical' as severity
WHERE (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE AND created_at < NOW() - INTERVAL '1 hour') > 0

UNION ALL

SELECT 
    'slow_projections' as alert_type,
    'Projection performance degraded' as message,
    'warning' as severity
WHERE (SELECT AVG(duration_ms) FROM projection_audit WHERE created_at > NOW() - INTERVAL '15 minutes') > 5000

UNION ALL

SELECT 
    'high_failure_rate' as alert_type,
    'High projection failure rate' as message,
    'warning' as severity
WHERE (
    SELECT COUNT(*) * 100.0 / NULLIF(COUNT(*), 0)
    FROM projection_audit 
    WHERE created_at > NOW() - INTERVAL '1 hour'
) > 10

UNION ALL

SELECT 
    'connection_limit' as alert_type,
    'Connection pool near limit' as message,
    'warning' as severity
WHERE (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = current_database()) > 80;

-- Performance trends
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_performance_trends AS
SELECT 
    DATE_TRUNC('minute', created_at) as minute,
    AVG(duration_ms) as avg_duration,
    MAX(duration_ms) as max_duration,
    COUNT(*) as total_calls,
    COUNT(CASE WHEN status = 'failure' THEN 1 END) as failures
FROM projection_audit
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('minute', created_at);

CREATE UNIQUE INDEX IF NOT EXISTS idx_perf_trends ON mv_performance_trends(minute);

-- Alert notification helper
CREATE OR REPLACE FUNCTION trigger_alert(
    p_alert_type TEXT,
    p_message TEXT,
    p_severity TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO notifications (tenant_id, user_id, title, body, notification_type)
    VALUES (NULL, NULL, p_alert_type, p_message, p_severity);
    
    PERFORM metrics_record('alerts_total', 1, jsonb_build_object('type', p_alert_type, 'severity', p_severity));
END;
$$ LANGUAGE plpgsql;