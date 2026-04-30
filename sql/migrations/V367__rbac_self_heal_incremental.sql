-- V367__rbac_self_heal_incremental.sql
-- Incremental self-heal: fix a subset of tables instead of all
CREATE OR REPLACE FUNCTION rbac.self_heal_incremental(_limit INTEGER DEFAULT 5) RETURNS VOID AS $${
DECLARE
  rec RECORD;
  updated INTEGER;
BEGIN
  FOR rec IN SELECT table_schema, table_name FROM rbac.list_can_path_tables() LIMIT COALESCE(_limit,5) LOOP
    updated := rbac.canonicalize_table_with_savepoint(rec.table_schema, rec.table_name);
    IF updated > 0 THEN
      -- option: log partial heal per table
      IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_event') THEN
        PERFORM rbac.log_canon_event(rec.table_schema, rec.table_name, updated);
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
