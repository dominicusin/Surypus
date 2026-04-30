-- V390__rbac_canonical_validate_all.sql
-- Validate canonicalization across all RBAC tables
CREATE OR REPLACE FUNCTION rbac.validate_all_can_paths() RETURNS JSONB AS $$
DECLARE
  rec RECORD;
  result JSONB := '[]'::JSONB;
  missing_cnt INTEGER;
  mismatch_cnt INTEGER;
BEGIN
  FOR rec IN (
    SELECT c1.table_schema AS schema_name, c1.table_name AS table_name
    FROM information_schema.columns c1
    JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
      AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
    WHERE c1.table_schema = 'rbac'
    GROUP BY c1.table_schema, c1.table_name
  ) LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL', rec.schema_name, rec.table_name) INTO missing_cnt;
    EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NOT NULL AND canonical_path <> path', rec.schema_name, rec.table_name) INTO mismatch_cnt;
    result := result || jsonb_build_object(
      'schema', rec.schema_name,
      'table', rec.table_name,
      'missing', COALESCE(missing_cnt,0),
      'mismatch', COALESCE(mismatch_cnt,0),
      'ok', (COALESCE(missing_cnt,0) = 0 AND COALESCE(mismatch_cnt,0) = 0)
    );
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
