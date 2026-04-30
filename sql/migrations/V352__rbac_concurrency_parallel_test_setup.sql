-- V352__rbac_concurrency_parallel_test_setup.sql
-- Setup for parallel concurrency tests (placeholders for CI orchestration)
DO $$
BEGIN
  -- Ensure the canonicalization environment is ready for parallel run tests
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_metrics') THEN
    RAISE NOTICE 'canon_metrics table missing; ensure V339/V314 patches create metrics';
  END IF;
END;
$$ LANGUAGE plpgsql;
