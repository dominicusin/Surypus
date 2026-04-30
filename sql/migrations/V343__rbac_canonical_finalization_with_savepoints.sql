-- V343__rbac_canonical_finalization_with_savepoints.sql
-- Per-table savepoint based canonicalization to allow partial success
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_with_savepoints() RETURNS VOID AS $$
DECLARE
  t RECORD;
  updated_count INT;
  total_updated INT := 0;
  details_json JSONB := '[]'::JSONB;
  spname TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'list_can_path_tables') THEN
    RAISE NOTICE 'rbac.list_can_path_tables missing — nothing to canonicalize';
    RETURN;
  END IF;

  FOR t IN SELECT schema_name, table_name FROM rbac.list_can_path_tables() LOOP
    spname := format('sp_%s_%s', t.schema_name, t.table_name);
    BEGIN
      EXECUTE format('SAVEPOINT %I', spname);
      EXECUTE format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', t.schema_name, t.table_name);
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      total_updated := total_updated + COALESCE(updated_count,0);
      details_json := jsonb_array_append(details_json, jsonb_build_object('schema', t.schema_name, 'table', t.table_name, 'updated', COALESCE(updated_count,0)));
      EXECUTE format('RELEASE SAVEPOINT %I', spname);
    EXCEPTION WHEN OTHERS THEN
      EXECUTE format('ROLLBACK TO SAVEPOINT %I', spname);
      RAISE NOTICE 'rbac canonicalize skipped table %.% due to error', t.schema_name, t.table_name;
    END;
  END LOOP;

  PERFORM rbac.log_canon_metrics(total_updated, details_json);
END;
$$ LANGUAGE plpgsql;
