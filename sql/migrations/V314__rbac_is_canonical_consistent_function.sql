-- V314__rbac_is_canonical_consistent_function.sql
-- Define a function to check canonicalization invariants
CREATE OR REPLACE FUNCTION rbac.is_canonical_consistent() RETURNS BOOLEAN AS $$
DECLARE
  cnt INTEGER;
  rec RECORD;
BEGIN
  -- Check all tables with path and canonical_path
  FOR rec IN (
    SELECT c1.table_schema, c1.table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)', rec.table_schema, rec.table_name) INTO cnt;
    IF cnt > 0 THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)' INTO cnt;
    IF cnt > 0 THEN
      RETURN FALSE;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
