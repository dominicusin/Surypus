-- V409__rbac_concurrency_backpressure_config.sql
-- Add a canonical backlog threshold in config and a function to compute ability to run with backpressure
CREATE OR REPLACE FUNCTION rbac.ensure_config_backpressure_defaults() RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key='canonical_backlog_threshold') THEN
    PERFORM rbac.set_config_int('canonical_backlog_threshold', 1000);
  END IF;
END;
$$ LANGUAGE plpgsql;

SELECT rbac.ensure_config_backpressure_defaults();

CREATE OR REPLACE FUNCTION rbac.can_run_with_backpressure() RETURNS BOOLEAN AS $$
DECLARE
  v_threshold INTEGER;
  v_backlog INTEGER;
BEGIN
  SELECT COALESCE(value::int, 1000) INTO v_threshold FROM rbac.config WHERE key = 'canonical_backlog_threshold' LIMIT 1;
  SELECT COUNT(*) INTO v_backlog FROM rbac.canon_queue WHERE status IN ('pending', 'in_progress');
  IF v_backlog > v_threshold THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
