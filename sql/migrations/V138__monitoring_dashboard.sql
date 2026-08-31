-- Monitoring dashboard for system health.
-- projection_audit is created by a later migration; build the view with or
-- without those two projection stats so it stays valid at any load order.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projection_audit') THEN
    EXECUTE 'CREATE OR REPLACE VIEW v_dashboard AS
      SELECT
          (SELECT COUNT(*) FROM event_store) as total_events,
          (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
          (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
          (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
          (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as unresolved_dlq,
          (SELECT COUNT(*) FROM projection_audit WHERE created_at > NOW() - INTERVAL ''1 hour'') as last_hour_projections,
          (SELECT COUNT(*) FROM projection_audit WHERE status = ''failure'' AND created_at > NOW() - INTERVAL ''1 hour'') as failed_projections,
          (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;';
  ELSE
    EXECUTE 'CREATE OR REPLACE VIEW v_dashboard AS
      SELECT
          (SELECT COUNT(*) FROM event_store) as total_events,
          (SELECT COUNT(DISTINCT aggregate_id) FROM event_store) as total_aggregates,
          (SELECT COUNT(*) FROM aggregate_snapshots) as total_snapshots,
          (SELECT COUNT(*) FROM event_outbox WHERE published = FALSE) as pending_outbox,
          (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) as unresolved_dlq,
          0::BIGINT as last_hour_projections,
          0::BIGINT as failed_projections,
          (SELECT MAX(recorded_at) FROM health_metrics) as last_health_check;';
  END IF;
END $$;

-- Active session stats
CREATE OR REPLACE VIEW v_active_sessions AS
SELECT
    usename as username,
    COUNT(*) as session_count,
    MAX(backend_start) as latest_session
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY usename;
