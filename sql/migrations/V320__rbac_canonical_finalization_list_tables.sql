-- V320__rbac_canonical_finalization_list_tables.sql
-- List RBAC tables that participate in canonicalization (path + canonical_path)
CREATE OR REPLACE FUNCTION rbac.list_can_path_tables() RETURNS TABLE(schema_name text, table_name text) AS $$
BEGIN
  RETURN QUERY
  SELECT c1.table_schema::text AS schema_name, c1.table_name::text AS table_name
  FROM information_schema.columns c1
  JOIN information_schema.columns c2
    ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
  WHERE c1.table_schema = 'rbac'
    AND c1.column_name = 'path'
    AND c2.column_name = 'canonical_path'
  GROUP BY c1.table_schema, c1.table_name
  HAVING SUM(CASE WHEN c1.column_name = 'path' THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN c2.column_name = 'canonical_path' THEN 1 ELSE 0 END) > 0;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  -- Ensure the function exists and is usable (idempotent creation)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'list_can_path_tables'
  ) THEN
    RAISE NOTICE 'rbac.list_can_path_tables function not found after creation';
  END IF;
END;
$$ LANGUAGE plpgsql;
