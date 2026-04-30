-- V392__rbac_concurrency_stress_runner_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'enqueue_multiple_can_tables') THEN
    PERFORM rbac.enqueue_multiple_can_tables(20);
  END IF;
END;
$$ LANGUAGE plpgsql;
