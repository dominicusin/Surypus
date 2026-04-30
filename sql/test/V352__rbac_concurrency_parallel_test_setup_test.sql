-- V352__rbac_concurrency_parallel_test_setup_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_metrics') THEN
    RAISE NOTICE 'canon_metrics exists; ready for parallel tests';
  END IF;
END;
$$ LANGUAGE plpgsql;
