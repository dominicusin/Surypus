-- V326__rbac_config_defaults_test.sql
-- Validate that default config entries exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key = 'canonical_batch_size') THEN
    RAISE EXCEPTION 'canonical_batch_size default not set';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM rbac.config WHERE key = 'canonical_lock_id') THEN
    RAISE EXCEPTION 'canonical_lock_id default not set';
  END IF;
  -- Quick sanity: ensure get_config_int works
  IF COALESCE(rbac.get_config_int('canonical_batch_size', 0), 0) = 0 THEN
    RAISE EXCEPTION 'get_config_int failed for canonical_batch_size';
  END IF;
END;
$$ LANGUAGE plpgsql;
