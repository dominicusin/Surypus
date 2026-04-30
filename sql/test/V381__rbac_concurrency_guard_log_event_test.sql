-- V381__rbac_concurrency_guard_log_event_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_concurrency_guard_event') THEN
    PERFORM rbac.log_concurrency_guard_event(1, 'rbac', 'canon_metrics', true, true, 'test');
  END IF;
END;
$$ LANGUAGE plpgsql;
