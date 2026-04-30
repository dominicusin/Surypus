-- V414__rbac_concurrency_stress_engine_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'run_concurrency_stress') THEN
    PERFORM rbac.run_concurrency_stress(3, 50);
  END IF;
END;
$$ LANGUAGE plpgsql;
