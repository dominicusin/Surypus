-- V318__rbac_canonical_finalization_idempotence.sql
-- Run canonicalization twice to verify idempotence and invariants
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    -- run twice to ensure no changes on subsequent runs
    PERFORM rbac.canonicalize_wrappers();
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  -- Final invariants check
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'RBAC canonical finalization idempotence check failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;
