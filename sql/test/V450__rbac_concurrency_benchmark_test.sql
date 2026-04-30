-- V450__rbac_concurrency_benchmark_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='rbac' AND routine_name='run_concurrency_benchmark') THEN
    PERFORM rbac.run_concurrency_benchmark(2, 5);
  END IF;
END;
$$ LANGUAGE plpgsql;
