-- V361__rbac_concurrency_heavy_testing_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'concurrent_batch_heavy_simulation') THEN
    PERFORM rbac.concurrent_batch_heavy_simulation(3, 50);
  END IF;
END;
$$ LANGUAGE plpgsql;
