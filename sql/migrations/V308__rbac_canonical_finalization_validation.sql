-- V308__rbac_canonical_finalization_validation.sql
-- Validation patch to ensure canonicalization completed for all rbac tables.
-- Idempotent: if the rbac schema / canonicalize_wrappers function are absent
-- (i.e. this feature was never created in this instance), the script logs a
-- NOTICE and exits cleanly rather than raising an exception.
DO $$
DECLARE
  t RECORD;
  nulls_in_table INTEGER := 0;
  dyn_sql TEXT;
  cnt INTEGER;
BEGIN
  -- Validate that canonicalize_wrappers function exists
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.routines
    WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers'
  ) THEN
    RAISE NOTICE 'RBAC canonical_finalization_validation: skipped (rbac.canonicalize_wrappers does not exist — feature not deployed)';
    RETURN;
  END IF;

  -- Run the canonicalization pass (idempotent)
  PERFORM rbac.canonicalize_wrappers();

  -- Check all rbac tables that have both path and canonical_path
  FOR t IN (
    SELECT c1.table_schema AS schema, c1.table_name AS table
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c2.column_name = 'canonical_path' AND c1.column_name = 'path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    dyn_sql := format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL', t.schema, t.table);
    EXECUTE dyn_sql INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'RBAC canonicalization incomplete: %.% has % NULL canonical_path(s)', t.schema, t.table, cnt;
    END IF;
  END LOOP;

  -- Optional: check wrapper table if present
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    EXECUTE 'SELECT COUNT(*) FROM rbac.wrapper WHERE canonical_path IS NULL' INTO cnt;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'RBAC canonicalization incomplete: rbac.wrapper has % NULL canonical_path(s)', cnt;
    END IF;
  END IF;

  RAISE NOTICE 'RBAC canonical_finalization_validation: OK';
END;
$$ LANGUAGE plpgsql;
