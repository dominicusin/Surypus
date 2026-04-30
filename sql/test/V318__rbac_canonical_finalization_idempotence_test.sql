-- V318__rbac_canonical_finalization_idempotence_test.sql
-- Execute double canonicalization to verify idempotence and invariants
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'RBAC canonical finalization idempotence test failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;
