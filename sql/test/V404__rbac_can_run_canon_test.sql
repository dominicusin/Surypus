-- V404__rbac_can_run_canon_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'can_run_canon') THEN
    -- simple invocation
    PERFORM rbac.can_run_canon();
  END IF;
END;
$$ LANGUAGE plpgsql;
