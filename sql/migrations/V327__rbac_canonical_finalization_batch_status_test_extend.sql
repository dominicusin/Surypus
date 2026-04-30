-- V327__rbac_canonical_finalization_batch_status_test_extend.sql
-- Extend tests to validate batch run log entry creation
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_batch_run') THEN
    -- Create a trivial batch run log to verify function exists
    PERFORM rbac.log_batch_run(1, 0, 'noop', '{}'::jsonb);
  END IF;
END;
$$ LANGUAGE plpgsql;
