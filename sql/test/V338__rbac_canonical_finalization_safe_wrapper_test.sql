-- V338__rbac_canonical_finalization_safe_wrapper_test.sql
-- Test safe wrapper behavior
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'safe_canonicalize_all') THEN
    PERFORM rbac.safe_canonicalize_all();
  END IF;
END;
$$ LANGUAGE plpgsql;
