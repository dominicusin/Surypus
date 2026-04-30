-- V451__rbac_canon_dequeue_next_table.sql
-- Bridge: fetch the next table for canonicalization using the round-robin generator
CREATE OR REPLACE FUNCTION rbac.dequeue_next_can_table()
RETURNS TABLE (schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM rbac.next_canon_table_round_robin();
END;
$$ LANGUAGE plpgsql;
