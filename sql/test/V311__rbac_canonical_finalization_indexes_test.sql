-- V311__rbac_canonical_finalization_indexes_test.sql
-- Verify index creation for rbac canonicalization tables
DO $$
DECLARE
  rec RECORD;
  idx_count INTEGER;
BEGIN
  -- Run the migration (index creation)
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    -- no-op: ensure the function exists
    PERFORM rbac.canonicalize_wrappers();
  END IF;

  -- Check that candidate indexes exist
  FOR rec IN (
    SELECT table_schema, table_name
    FROM information_schema.columns
    WHERE column_name = 'canonical_path' AND table_schema = 'rbac'
    GROUP BY table_schema, table_name
  ) LOOP
    EXECUTE format('SELECT count(*) FROM pg_class WHERE relname = ''idx_%I_%I_can_path''', rec.table_schema, rec.table_name) INTO idx_count;
    IF idx_count = 0 THEN
      RAISE EXCEPTION 'Index not found for %I.%I', rec.table_schema, rec.table_name;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
