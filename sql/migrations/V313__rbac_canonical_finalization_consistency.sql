-- V313__rbac_canonical_finalization_consistency.sql
-- Validate that canonical_path invariants hold after canonicalization
DO $$
DECLARE
  rec RECORD;
  cnt INTEGER := 0;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;

  -- Check all tables with path and canonical_path
  FOR rec IN (
    SELECT table_schema, table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY table_schema, table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)', rec.table_schema, rec.table_name) INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'Inconsistency: %.% has % rows with path != canonical_path', rec.table_schema, rec.table_name, cnt;
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE path IS NOT NULL AND (canonical_path IS NULL OR canonical_path <> path)' INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'Inconsistency: rbac.wrapper has % rows with path != canonical_path', cnt;
    END IF;
  END IF;

  RAISE NOTICE 'RBAC canonical_finalization_consistency: OK';
END;
$$ LANGUAGE plpgsql;
