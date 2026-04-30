-- V356__rbac_config_logging.sql
-- Audit log table and helper for config changes
CREATE TABLE IF NOT EXISTS rbac.config_log (
  id BIGSERIAL PRIMARY KEY,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  key TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_by TEXT,
  reason TEXT
);

CREATE OR REPLACE FUNCTION rbac.log_config_change(_key TEXT, _old TEXT, _new TEXT, _by TEXT, _reason TEXT) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.config_log (key, old_value, new_value, changed_by, reason) VALUES (_key, _old, _new, _by, _reason);
END;
$$ LANGUAGE plpgsql;
