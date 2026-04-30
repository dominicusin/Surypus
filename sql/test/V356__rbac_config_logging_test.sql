-- V356__rbac_config_logging_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_config_change') THEN
    -- log a sample change
    PERFORM rbac.log_config_change('canonical_batch_size', '1024', '2048', 'tester', 'test increment');
    IF NOT EXISTS (SELECT 1 FROM rbac.config_log WHERE key = 'canonical_batch_size' AND old_value = '1024' AND new_value = '2048') THEN
      RAISE EXCEPTION 'config log not recorded';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
