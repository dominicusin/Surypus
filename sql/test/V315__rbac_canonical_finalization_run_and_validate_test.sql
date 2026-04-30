-- V315__rbac_canonical_finalization_run_and_validate_test.sql
-- Execute the run+validate patch and ensure no exceptions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'RBAC canonical finalization run and validate test failed';
  END IF;
END;
$$ LANGUAGE plpgsql;
