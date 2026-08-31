-- System summary view.
-- projection_audit is created by a later migration; build the view with or
-- without those two projection stats so it stays valid at any load order.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projection_audit') THEN
    EXECUTE 'CREATE OR REPLACE VIEW v_system_summary AS
      SELECT
          (SELECT COUNT(*) FROM event_store) as total_events,
          (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
          (SELECT COUNT(DISTINCT tenant_id) FROM event_store) as total_tenants,
          (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
          (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
          (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as dlq_pending,
          (SELECT COUNT(*) FROM projections) as total_projections,
          (SELECT COUNT(*) FROM projection_audit WHERE created_at > NOW() - INTERVAL ''1 hour'') as projection_runs_1h,
          (SELECT AVG(duration_ms)::INT FROM projection_audit WHERE created_at > NOW() - INTERVAL ''1 hour'') as avg_projection_ms,
          (SELECT COUNT(*) FROM users WHERE is_active = TRUE) as active_users,
          (SELECT COUNT(*) FROM api_keys WHERE is_active = TRUE) as active_api_keys,
          (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;';
  ELSE
    EXECUTE 'CREATE OR REPLACE VIEW v_system_summary AS
      SELECT
          (SELECT COUNT(*) FROM event_store) as total_events,
          (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
          (SELECT COUNT(DISTINCT tenant_id) FROM event_store) as total_tenants,
          (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
          (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
          (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as dlq_pending,
          (SELECT COUNT(*) FROM projections) as total_projections,
          0::BIGINT as projection_runs_1h,
          0::INT as avg_projection_ms,
          (SELECT COUNT(*) FROM users WHERE is_active = TRUE) as active_users,
          (SELECT COUNT(*) FROM api_keys WHERE is_active = TRUE) as active_api_keys,
          (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;';
  END IF;
END $$;

-- Final system check
DO $$
DECLARE
    v_status TEXT := 'healthy';
BEGIN
    IF (SELECT COUNT(*) FROM event_store) < 0 THEN
        v_status := 'critical';
    END IF;
    IF (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) > 1000 THEN
        v_status := 'degraded';
    END IF;
    RAISE NOTICE 'System status: %', v_status;
END $$;

-- (Informational NOTICEs moved into the DO block above would require a function;
-- left as plain comments to keep the migration a valid SQL script.)
-- Surypus SQL Refactoring Complete! Version: 151+ migrations applied.
-- Features: RBAC, Partitioning, Projections, Monitoring, Analytics.
