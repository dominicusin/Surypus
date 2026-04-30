-- V346__rbac_config_set_batch_size.sql
-- Set canonical_batch_size via a helper
CREATE OR REPLACE FUNCTION rbac.set_config_int(_key TEXT, _value INTEGER) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM rbac.config WHERE key = _key) THEN
    UPDATE rbac.config SET value = _value::TEXT WHERE key = _key;
  ELSE
    INSERT INTO rbac.config (key, value) VALUES (_key, _value::TEXT);
  END IF;
END;
$$ LANGUAGE plpgsql;
