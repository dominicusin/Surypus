-- V307__rbac_canonical_finalization.sql
-- Real canonicalization logic for RBAC wrappers
DO $$
DECLARE
  rec RECORD;
  dyn_sql TEXT;
  total_updated INT := 0;
  updated_count INT;
BEGIN
  -- Canonicalize wrappers that have both path and canonical_path columns
  FOR rec IN
    SELECT table_schema, table_name
    FROM information_schema.columns
    WHERE table_schema = 'rbac'
      AND column_name IN ('path', 'canonical_path')
  GROUP BY table_schema, table_name
  HAVING SUM(CASE WHEN column_name = 'path' THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN column_name = 'canonical_path' THEN 1 ELSE 0 END) > 0
  LOOP
    dyn_sql := format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', rec.table_schema, rec.table_name);
    EXECUTE dyn_sql;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    total_updated := total_updated + COALESCE(updated_count,0);
    RAISE NOTICE 'rbac canonicalize: %.% updated % rows', rec.table_schema, rec.table_name, COALESCE(updated_count,0);
  END LOOP;

  -- Align wrapper table if present
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'wrapper') THEN
    dyn_sql := 'UPDATE rbac.wrapper SET canonical_path = path WHERE canonical_path IS NULL';
    EXECUTE dyn_sql;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    total_updated := total_updated + COALESCE(updated_count,0);
    RAISE NOTICE 'rbac.wrapper canonicalized: updated % rows', COALESCE(updated_count,0);
  END IF;

  IF total_updated > 0 THEN
    RAISE NOTICE 'rbac canonicalization complete: total_updated=%', total_updated;
  ELSE
    RAISE NOTICE 'rbac canonicalization complete: no updates needed';
  END IF;
END;
$$ LANGUAGE plpgsql;
