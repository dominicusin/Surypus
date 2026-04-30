-- V452__rbac_canon_round_robin_step.sql
-- Single step: take the next table via round-robin and canonize it
CREATE OR REPLACE FUNCTION rbac.canon_round_robin_step() RETURNS BOOLEAN AS $$
DECLARE
  rec RECORD;
  updated INT;
BEGIN
  -- fetch next target table
  FOR rec IN SELECT * FROM rbac.next_canon_table_round_robin() LOOP
    BEGIN
      PERFORM rbac.canonicalize_table(rec.schema_name, rec.table_name);
      updated := 1;
      EXIT; -- only one table per step
    EXCEPTION WHEN OTHERS THEN
      updated := 0;
      EXIT;
    END;
  END LOOP;
  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql;
