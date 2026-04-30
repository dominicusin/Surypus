-- V416__rbac_config_dynamic_limits_test.sql
DO $$
BEGIN
  PERFORM rbac.ensure_config_dynamic_limits();
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key='canonical_backlog_threshold') THEN
    RAISE EXCEPTION 'missing canonical_backlog_threshold';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key='canonical_batch_size_goal') THEN
    RAISE EXCEPTION 'missing canonical_batch_size_goal';
  END IF;
END;
$$ LANGUAGE plpgsql;
