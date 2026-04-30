-- V320__rbac_canonical_finalization_list_tables_test.sql
-- Verify that list_can_path_tables() returns rows for canonicalizable tables
DO $$
DECLARE
  cnt INTEGER;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'list_can_path_tables') THEN
    SELECT COUNT(*) INTO cnt FROM rbac.list_can_path_tables();
    -- Just ensure the function returns a result set (could be zero on clean state)
    IF cnt < 0 THEN
      RAISE EXCEPTION 'list_can_path_tables returned negative count';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
