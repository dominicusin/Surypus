-- V388__rbac_concurrency_backlog_alerts.sql
-- Simple backlog alert rules for canon_queue
CREATE OR REPLACE FUNCTION rbac.backlog_alerts() RETURNS VOID AS $$
DECLARE
  backlog INTEGER;
BEGIN
  SELECT count(*) INTO backlog FROM rbac.canon_queue WHERE status = 'pending';
  IF backlog > 100 THEN
    RAISE NOTICE 'Canon backlog alert: % pending tasks', backlog;
  END IF;
END;
$$ LANGUAGE plpgsql;
