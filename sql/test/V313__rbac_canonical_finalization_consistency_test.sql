-- V313__rbac_canonical_finalization_consistency_test.sql
-- Ensure invariants hold after canonicalization
DO $$
DECLARE
  ok BOOLEAN;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  ok := rbac.is_canonical_consistent();
  IF NOT ok THEN
    RAISE EXCEPTION 'RBAC canonical finalization consistency check failed';
  END IF;
END;
$$ LANGUAGE plpgsql;
