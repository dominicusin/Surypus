-- V325__rbac_canonical_finalization_batch.sql
-- Batch canonicalization to minimize lock duration with circuit breaker protection
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_batch(batch_size INTEGER DEFAULT 1000) RETURNS VOID AS $$
DECLARE
  tbl RECORD;
  updated_count INT;
  total_updated INT := 0;
  sql TEXT;
  should_proceed BOOLEAN;
BEGIN
  -- Check circuit breaker before proceeding
  should_proceed := rbac.check_canon_circuit_breaker();
  IF NOT should_proceed THEN
    RAISE NOTICE 'rbac.canonicalize_all_batch: Circuit breaker open, skipping execution';
    RETURN;
  END IF;
  
  -- Resolve batch_size from config if not provided
  IF batch_size IS NULL THEN
    batch_size := COALESCE((SELECT value::int FROM rbac.config WHERE key = 'canonical_batch_size' LIMIT 1), 1000);
  END IF;
  
  -- Acquire a lock to prevent concurrent batch canonicalizations
  PERFORM pg_advisory_lock(123456789);
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'list_can_path_tables') THEN
    RAISE NOTICE 'rbac.list_can_path_tables missing — nothing to canonicalize';
    PERFORM pg_advisory_unlock(123456789);
    RETURN;
  END IF;
  FOR tbl IN SELECT schema_name, table_name FROM rbac.list_can_path_tables() LOOP
    LOOP
      sql := format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL AND ctid IN (SELECT ctid FROM %I.%I WHERE canonical_path IS NULL LIMIT %s)', tbl.schema_name, tbl.table_name, tbl.schema_name, tbl.table_name, batch_size);
      EXECUTE sql;
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      total_updated := total_updated + COALESCE(updated_count,0);
      EXIT WHEN updated_count = 0;
    END LOOP;
  END LOOP;
  PERFORM rbac.log_canon_metrics(total_updated, jsonb_build_object('scope','canonicalize_all_batch','batch', batch_size, 'total', total_updated));
  RAISE NOTICE 'rbac.canonicalize_all_batch finished: total_updated=%', total_updated;
  -- Update circuit breaker on success
  PERFORM rbac.update_canon_circuit_breaker(TRUE);
  PERFORM pg_advisory_unlock(123456789);
END;
$$ LANGUAGE plpgsql;