-- V426__rbac_config_logs_purge.sql
-- Purge old config logs older than a given number of days
CREATE OR REPLACE FUNCTION rbac.purge_config_logs(_older_days INTEGER DEFAULT 90) RETURNS INTEGER AS $$
DECLARE
  cutoff TIMESTAMPTZ := NOW() - INTERVAL '1 day' * COALESCE(_older_days, 90);
  delcnt INTEGER;
BEGIN
  DELETE FROM rbac.config_log WHERE created_at < cutoff RETURNING id INTO delcnt;
  GET DIAGNOSTICS delcnt = ROW_COUNT;
  RETURN COALESCE(delcnt,0);
END;
$$ LANGUAGE plpgsql;
