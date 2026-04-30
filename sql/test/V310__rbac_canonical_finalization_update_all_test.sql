-- V310__rbac_canonical_finalization_update_all_test.sql
-- Thorough test to ensure no NULL canonical_path remain after thorough pass
DO $$
DECLARE
  rec RECORD;
  cnt INTEGER;
BEGIN
  -- Run the thorough canonicalization
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;

  -- Validate all tables with path and canonical_path
  FOR rec IN (
    SELECT c1.table_schema AS schema, c1.table_name AS table
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c2.table_schema = c1.table_schema AND c2.table_name = c1.table_name
    WHERE c1.column_name = 'path' AND c2.column_name = 'canonical_path' AND c1.table_schema = 'rbac'
    GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL OR canonical_path <> path', rec.schema, rec.table) INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'Canonicalization check failed: %.% has % mismatches', rec.schema, rec.table, cnt;
    END IF;
  END LOOP;

  -- Check wrapper table if present
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE canonical_path IS NULL OR canonical_path <> path' INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'RBAC wrapper canonicalization check failed: % mismatches', cnt;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
