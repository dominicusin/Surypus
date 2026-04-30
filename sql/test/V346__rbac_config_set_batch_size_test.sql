-- V346__rbac_config_set_batch_size_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'set_config_int') THEN
    PERFORM rbac.set_config_int('canonical_batch_size', 2048);
    IF (SELECT value FROM rbac.config WHERE key = 'canonical_batch_size') <> '2048' THEN
      RAISE EXCEPTION 'Failed to set canonical_batch_size';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
