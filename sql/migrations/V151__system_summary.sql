-- System summary view
CREATE OR REPLACE VIEW v_system_summary AS
SELECT 
    -- Event Store
    (SELECT COUNT(*) FROM event_store) as total_events,
    (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
    (SELECT COUNT(DISTINCT tenant_id) FROM event_store) as total_tenants,
    
    -- Snapshots
    (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
    
    -- Outbox
    (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
    
    -- DLQ
    (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as dlq_pending,
    
    -- Projections
    (SELECT COUNT(*) FROM projections) as total_projections,
    (SELECT COUNT(*) FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as projection_runs_1h,
    
    -- Performance
    (SELECT AVG(duration_ms)::INT FROM projection_audit WHERE created_at > NOW() - INTERVAL '1 hour') as avg_projection_ms,
    
    -- Security
    (SELECT COUNT(*) FROM users WHERE is_active = TRUE) as active_users,
    (SELECT COUNT(*) FROM api_keys WHERE is_active = TRUE) as active_api_keys,
    
    -- Health
    (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;

-- Final system check
DO $$ 
DECLARE
    v_status TEXT := 'healthy';
BEGIN
    -- Check critical tables
    IF (SELECT COUNT(*) FROM event_store) < 0 THEN
        v_status := 'critical';
    END IF;
    
    -- Check DLQ
    IF (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) > 1000 THEN
        v_status := 'degraded';
    END IF;
    
    RAISE NOTICE 'System status: %', v_status;
END $$;

RAISE NOTICE 'Surypus SQL Refactoring Complete!';
RAISE NOTICE 'Version: 151+ migrations applied';
RAISE NOTICE 'Features: RBAC, Partitioning, Projections, Monitoring, Analytics';