-- V380__rbac_canonical_batch_savepoints.sql
-- Per-table savepoints with a batch limit to enable partial canonicalization
CREATE OR REPLACE FUNCTION rbac.canonical_batch_with_savepoints(_max_tables INTEGER DEFAULT 10) RETURNS INTEGER AS $$
DECLARE
  rec RECORD;
  updated_count INTEGER := 0;
  total_updated INTEGER := 0;
  savept TEXT;
  cnt INTEGER := 0;
BEGIN
  IF _max_tables IS NULL OR _max_tables < 1 THEN
    _max_tables := 10;
  END IF;
  savept := 'cp_batch';
  -- Iterate through tables to canonicalize with per-table savepoints
  FOR rec IN SELECT table_schema, table_name FROM rbac.list_can_path_tables() LOOP
    EXIT WHEN total_updated >= _max_tables;
    BEGIN
      EXECUTE format('SAVEPOINT %I', savept || '_' || rec.table_name);
      EXECUTE format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', rec.table_schema, rec.table_name);
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      total_updated := total_updated + COALESCE(updated_count,0);
      -- Optionally log per-table update
      IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_event') THEN
        PERFORM rbac.log_canon_event(rec.table_schema, rec.table_name, COALESCE(updated_count,0));
      END IF;
      EXECUTE format('RELEASE SAVEPOINT %I', savept || '_' || rec.table_name);
    EXCEPTION WHEN OTHERS THEN
      EXECUTE format('ROLLBACK TO SAVEPOINT %I', savept || '_' || rec.table_name);
      -- continue with next table
      RAISE;
    END;
    cnt := cnt + 1;
  END LOOP;
  -- Log final metrics for this batch
  PERFORM rbac.log_canon_metrics(total_updated, jsonb_build_object('batch_size', _max_tables, 'batch_total', total_updated));
  RETURN total_updated;
END;
$$ LANGUAGE plpgsql;
