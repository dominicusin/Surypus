-- V422__rbac_prometheus_priority_metrics.sql
-- Extend Prometheus metrics with per-priority backlog exposition
CREATE OR REPLACE FUNCTION rbac.prometheus_priority_metrics() RETURNS TEXT AS $$
DECLARE
  rec RECORD;
  out TEXT := '';
BEGIN
  FOR rec IN (
    SELECT priority, COUNT(*) AS cnt
    FROM rbac.canon_queue
    WHERE status = 'pending'
    GROUP BY priority
    ORDER BY priority DESC
  ) LOOP
    out := out || format('canon_queue_priority{priority=%d} %s\n', rec.priority, rec.cnt);
  END LOOP;
  RETURN out;
END;
$$ LANGUAGE plpgsql;
