-- V343__rbac_canonical_finalization_with_savepoints_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_with_savepoints') THEN
    PERFORM rbac.canonicalize_all_with_savepoints();
  END IF;
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'canonicalize_all_with_savepoints test failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;
