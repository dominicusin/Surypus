-- V416__rbac_config_dynamic_limits.sql
-- Add dynamic limits for canonicalization backlog and batching thresholds
CREATE OR REPLACE FUNCTION rbac.ensure_config_dynamic_limits() RETURNS VOID AS $$
BEGIN
  -- backlog threshold
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key='canonical_backlog_threshold') THEN
    INSERT INTO rbac.config (key, value) VALUES ('canonical_backlog_threshold','1000');
  END IF;
  -- batch size goal for dynamic tuning
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key='canonical_batch_size_goal') THEN
    INSERT INTO rbac.config (key, value) VALUES ('canonical_batch_size_goal','1000');
  END IF;
END;
$$ LANGUAGE plpgsql;

SELECT rbac.ensure_config_dynamic_limits();
