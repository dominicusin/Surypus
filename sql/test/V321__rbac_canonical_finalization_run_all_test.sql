-- V321__rbac_canonical_finalization_run_all_test.sql
-- Run canonicalize_all() and verify invariants
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all') THEN
    PERFORM rbac.canonicalize_all();
  END IF;
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'RBAC canonical_finalization_run_all_test failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;
