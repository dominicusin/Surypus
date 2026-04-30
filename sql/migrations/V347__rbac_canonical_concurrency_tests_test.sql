-- V347__rbac_canonical_concurrency_tests_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
    PERFORM rbac.canonicalize_all();
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac.canonicalize_all_batch(20);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'is_canonical_consistent') THEN
    IF NOT rbac.is_canonical_consistent() THEN
      RAISE EXCEPTION 'concurrency test: invariant violated';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
