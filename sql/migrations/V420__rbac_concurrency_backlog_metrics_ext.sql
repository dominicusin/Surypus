-- V420__rbac_concurrency_backlog_metrics_ext.sql
-- Extend backlog metrics collection for canonicalization
CREATE OR REPLACE FUNCTION rbac.collect_backlog_metrics() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  result JSONB := '[]'::JSONB;
  backlog_count INTEGER;
BEGIN
  FOR rec IN (
    SELECT table_schema, table_name, COUNT(*) AS backlog, MAX(COALESCE(priority,0)) AS max_priority
    FROM rbac.canon_queue
    WHERE status = 'pending'
    GROUP BY table_schema, table_name
  ) LOOP
    backlog_count := rec.backlog;
    result := result || jsonb_build_object(
      'schema', rec.table_schema,
      'table', rec.table_name,
      'backlog', backlog_count,
      'max_priority', COALESCE(rec.max_priority, 0)
    );
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
