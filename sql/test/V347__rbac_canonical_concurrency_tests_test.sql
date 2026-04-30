-- V347__rbac_canonical_concurrency_tests_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac.canonicalize_all_batch(1000);
  END IF;
END;
$$ LANGUAGE plpgsql;
