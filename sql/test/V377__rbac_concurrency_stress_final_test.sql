-- V377__rbac_concurrency_stress_final_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'concurrency_stress_run') THEN
    PERFORM rbac.concurrency_stress_run(2, 20);
  END IF;
END;
$$ LANGUAGE plpgsql;
