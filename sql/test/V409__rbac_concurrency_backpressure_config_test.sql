-- V409__rbac_concurrency_backpressure_config_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'can_run_with_backpressure') THEN
    -- Just call to ensure function compiles; actual backlog value depends on current data
    PERFORM rbac.can_run_with_backpressure();
  END IF;
END;
$$ LANGUAGE plpgsql;
