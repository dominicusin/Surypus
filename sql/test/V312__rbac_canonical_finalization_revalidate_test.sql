-- V312__rbac_canonical_finalization_revalidate_test.sql
-- Run revalidate and ensure no NULL canonical_path remain
DO $$
DECLARE
  rec RECORD;
  cnt INTEGER;
BEGIN
  -- Re-run canonicalization if available
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  -- Check all rbac tables with path & canonical_path
  FOR rec IN (
    SELECT c1.table_schema AS schema, c1.table_name AS table
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL', rec.schema, rec.table) INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'Revalidate failed: %.% has % NULL canonical_path(s)', rec.schema, rec.table, cnt;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
