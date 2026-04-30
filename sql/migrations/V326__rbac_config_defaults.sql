-- V326__rbac_config_defaults.sql
-- Initialize RBAC config table and default values for canonicalization
DO $$
BEGIN
  -- Create config table if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'config'
  ) THEN
    EXECUTE 'CREATE TABLE rbac.config (
      key TEXT PRIMARY KEY,
      value TEXT
    )';
  END IF;
  -- Seed default values if missing
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key = 'canonical_batch_size') THEN
    EXECUTE 'INSERT INTO rbac.config (key, value) VALUES (''canonical_batch_size'', ''1000'')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key = 'canonical_lock_id') THEN
    EXECUTE 'INSERT INTO rbac.config (key, value) VALUES (''canonical_lock_id'', ''123456789'')';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Optional helper: get_config_int
CREATE OR REPLACE FUNCTION rbac.get_config_int(_key TEXT, _default INTEGER) RETURNS INTEGER AS $$
BEGIN
  RETURN COALESCE((SELECT value::integer FROM rbac.config WHERE key = _key LIMIT 1), _default);
END;
$$ LANGUAGE plpgsql;
