-- V312__rbac_canonical_finalization_revalidate.sql
-- Re-validate invariants after canonicalization
DO $$
DECLARE
  t RECORD;
  cnt INTEGER;
  dyn_sql TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    PERFORM rbac.canonicalize_wrappers();
  END IF;
  -- Post-check: ensure no NULL canonical_path remain in rbac paths
  FOR t IN (
    SELECT table_schema, table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY table_schema, table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL', t.table_schema, t.table_name) INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'Canonicalization invariant violated: %.% has % NULL canonical_path(s)', t.table_schema, t.table_name, cnt;
    END IF;
  END LOOP;
  -- wrapper table safety
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE canonical_path IS NULL' INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'RBAC.wrapper invariant violated: % NULL canonical_path(s)', cnt;
    END IF;
  END IF;
  RAISE NOTICE 'RBAC canonical_finalization_revalidate: OK';
END;
$$ LANGUAGE plpgsql;
