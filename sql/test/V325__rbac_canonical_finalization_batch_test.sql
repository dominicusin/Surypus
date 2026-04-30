-- V325__rbac_canonical_finalization_batch_test.sql
-- Run batch canonicalization and ensure invariants hold
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_batch') THEN
    PERFORM rbac.canonicalize_all_batch(1000);
  END IF;
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'RBAC canonical_finalization_batch_test failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;