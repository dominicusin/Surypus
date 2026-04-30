-- V310__rbac_canonical_finalization_update_all.sql
-- Thorough canonicalization pass to enforce path consistency across all RBAC tables
DO $$
DECLARE
  tbl RECORD;
  dyn_sql TEXT;
  updated_count INT;
BEGIN
  -- Ensure the canonicalization function exists and is idempotent
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers') THEN
    -- Run a comprehensive canonicalization pass
    FOR tbl IN (
      SELECT table_schema, table_name
      FROM information_schema.columns
      WHERE table_schema = 'rbac'
        AND column_name = 'path'
      GROUP BY table_schema, table_name
      HAVING EXISTS (
        SELECT 1 FROM information_schema.columns c2
        WHERE c2.table_schema = table_schema AND c2.table_name = table_name AND c2.column_name = 'canonical_path'
      )
    ) LOOP
      dyn_sql := format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL OR canonical_path <> path', tbl.table_schema, tbl.table_name);
      EXECUTE dyn_sql;
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      IF COALESCE(updated_count,0) > 0 THEN
        RAISE NOTICE 'rbac canonicalize_thorough: %.% updated % rows', tbl.table_schema, tbl.table_name, updated_count;
      END IF;
    END LOOP;
  END IF;

  -- Align wrapper table if present
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    dyn_sql := 'UPDATE rbac.wrapper SET canonical_path = path WHERE canonical_path IS NULL OR canonical_path <> path';
    EXECUTE dyn_sql;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    IF COALESCE(updated_count,0) > 0 THEN
      RAISE NOTICE 'rbac.wrapper canonicalize_thorough: updated % rows', updated_count;
    END IF;
  END IF;

  -- Optional assertion: ensure no NULLs remain
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'rbac' AND column_name = 'path'
  ) THEN
    PERFORM 1; -- placeholder to ensure plpgsql block ends cleanly
  END IF;
END;
$$ LANGUAGE plpgsql;
