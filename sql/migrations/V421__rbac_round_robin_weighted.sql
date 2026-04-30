-- V421__rbac_round_robin_weighted.sql
-- Implement weighted round-robin selection for canon Kanon tables
CREATE OR REPLACE FUNCTION rbac.next_canon_table_weighted_round_robin()
RETURNS TABLE (schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT c.table_schema AS schema_name, c.table_name AS table_name
  FROM (SELECT table_schema, table_name FROM rbac.list_can_path_tables()) AS c
  ORDER BY COALESCE((SELECT priority FROM rbac.canon_queue q WHERE q.table_schema = c.table_schema AND q.table_name = c.table_name AND q.status = 'pending'), 0) DESC, md5(c.table_schema || '.' || c.table_name) ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;
