-- V453__rbac_round_robin_integration.sql
-- Integrate round-robin driver into canonicalization main loop (simplified)
CREATE OR REPLACE FUNCTION rbac.canonize_next_via_rr() RETURNS BOOLEAN AS $$
DECLARE
  tbl RECORD;
  updated_count INT;
BEGIN
  FOR tbl IN SELECT schema_name, table_name FROM rbac.next_canon_table_round_robin() LOOP
    PERFORM rbac.canonicalize_table(tbl.schema_name, tbl.table_name);
    updated_count := ROW_COUNT;
    EXIT; -- process only one per invocation for modularity
  END LOOP;
  RETURN (ROW_COUNT > 0);
END;
$$ LANGUAGE plpgsql;
