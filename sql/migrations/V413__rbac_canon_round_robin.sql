-- V413__rbac_canon_round_robin.sql
-- Introduce a deterministic round-robin selector for canonic tables
CREATE OR REPLACE FUNCTION rbac.next_canon_table_round_robin()
RETURNS TABLE (schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT table_schema AS schema_name, table_name
  FROM rbac.list_can_path_tables()
  ORDER BY md5(table_schema || '.' || table_name)
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;
