-- V376__rbac_concurrency_guard_logging_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'record_lock_attempt') THEN
    PERFORM rbac.record_lock_attempt(123456789, 'rbac', 'canon_metrics', true, true, 'test');
  END IF;
END;
$$ LANGUAGE plpgsql;
