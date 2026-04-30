-- V389__rbac_lock_cleanup_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_lock_history_cleanup') THEN
    -- placeholder for cleanup test invocation
    NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;
