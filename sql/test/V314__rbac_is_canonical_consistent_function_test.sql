-- V314__rbac_is_canonical_consistent_function_test.sql
-- Validate the function returns true on a canonicalized DB
DO $$
DECLARE
  ok BOOLEAN;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'is_canonical_consistent') THEN
    ok := rbac.is_canonical_consistent();
    IF NOT ok THEN
      RAISE EXCEPTION 'rbac.is_canonical_consistent() reported inconsistency';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
