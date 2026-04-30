-- V316__rbac_canonical_finalization_count_inconsistencies_test.sql
-- Validate that inconsistency counter reports zero on canonicalized DB
DO $$
DECLARE
  total INTEGER;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'count_canon_inconsistencies') THEN
    total := rbac.count_canon_inconsistencies();
    IF total > 0 THEN
      RAISE EXCEPTION 'Canonicalization inconsistency count is %', total;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
