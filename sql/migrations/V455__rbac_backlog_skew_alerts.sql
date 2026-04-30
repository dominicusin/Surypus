-- V455__rbac_backlog_skew_alerts.sql
-- Compute backlog skew across canon_queue and raise alert if skew large
CREATE OR REPLACE FUNCTION rbac.backlog_skew_alert(_threshold INT DEFAULT 50) RETURNS VOID AS $$
DECLARE
  max_backlog INT;
  min_backlog INT;
  skew INT;
BEGIN
  SELECT MAX(backlog), MIN(backlog) INTO max_backlog, min_backlog
  FROM (SELECT COUNT(*) AS backlog FROM rbac.canon_queue WHERE status = 'pending' GROUP BY table_schema, table_name) s;
  IF max_backlog IS NULL OR min_backlog IS NULL THEN
    RETURN;
  END IF;
  skew := max_backlog - min_backlog;
  IF skew > _threshold THEN
    RAISE NOTICE 'Backlog skew alert: max=%, min=%, skew=%', max_backlog, min_backlog, skew;
  END IF;
END;
$$ LANGUAGE plpgsql;
