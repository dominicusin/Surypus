-- V454__rbac_concurrency_latency_metrics.sql
-- Collect latency metrics for canonicalization of the last N completions
CREATE OR REPLACE FUNCTION rbac.collect_latency_metrics() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  arr JSONB := '[]'::JSONB;
  latency NUMERIC;
  limit_rows INTEGER := 100;
BEGIN
  FOR rec IN (
    SELECT table_schema, table_name, started_at, finished_at
    FROM rbac.canon_queue
    WHERE status = 'completed'
    ORDER BY finished_at DESC
    LIMIT limit_rows
  ) LOOP
    IF rec.finished_at IS NOT NULL AND rec.started_at IS NOT NULL THEN
      latency := EXTRACT(EPOCH FROM (rec.finished_at - rec.started_at));
      arr := arr || jsonb_build_object('schema', rec.table_schema, 'table', rec.table_name, 'latency_sec', latency);
    END IF;
  END LOOP;
  RETURN arr;
END;
$$ LANGUAGE plpgsql;
