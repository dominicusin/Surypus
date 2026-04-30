-- V321__rbac_canonical_finalization_run_all.sql
-- Orchestrate canonicalization across all tables with circuit breaker protection
CREATE OR REPLACE FUNCTION rbac.canonicalize_all() RETURNS VOID AS $$
DECLARE
  t RECORD;
  updated_count INT;
  total_updated INT := 0;
  details_json JSONB := '[]'::JSONB;
  v_next TIMESTAMPTZ;
  v_incons INTEGER;
  batch_size INTEGER := 1000; -- Default, can be overridden by config
  should_proceed BOOLEAN;
BEGIN
  -- Gate by can_run (concurrency control) and cooldown
  should_proceed := rbac.can_run_canon();
  -- If cooldown is active, skip early (can_run handles that, but keep verbose log)
  IF EXISTS (SELECT 1 FROM rbac.canon_circuit_breaker WHERE id = 1) THEN
    SELECT next_attempt_time INTO v_next FROM rbac.canon_circuit_breaker WHERE id = 1;
    IF v_next IS NOT NULL AND v_next > NOW() THEN
      RAISE NOTICE 'rbac.canonicalize_all: cooldown until %', v_next;
      PERFORM pg_advisory_unlock(123456789);
      RETURN;
    END IF;
  END IF;
  IF NOT should_proceed THEN
    RAISE NOTICE 'rbac.canonicalize_all: Circuit breaker open, skipping execution';
    RETURN;
  END IF;
  
  -- Resolve batch_size from config if not provided
  IF batch_size IS NULL THEN
    batch_size := COALESCE((SELECT value::int FROM rbac.config WHERE key = 'canonical_batch_size' LIMIT 1), 1000);
  END IF;
  
  -- Acquire advisory lock to prevent concurrent canonicalization runs
  PERFORM pg_advisory_lock(123456789);
  BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'list_can_path_tables') THEN
      FOR t IN SELECT schema_name, table_name FROM rbac.list_can_path_tables() LOOP
        EXECUTE format('UPDATE %I.%I SET canonical_path = path WHERE canonical_path IS NULL', t.schema_name, t.table_name);
        GET DIAGNOSTICS updated_count = ROW_COUNT;
        total_updated := total_updated + COALESCE(updated_count,0);
        details_json := jsonb_array_append(details_json, jsonb_build_object('schema', t.schema_name, 'table', t.table_name, 'updated', COALESCE(updated_count,0)));
        -- Emit per-table canonicalization event if the hook exists
        IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_event') THEN
          PERFORM rbac.log_canon_event(t.schema_name, t.table_name, COALESCE(updated_count,0));
        END IF;
      END LOOP;
    END IF;
    PERFORM rbac.log_canon_metrics(total_updated, details_json);
    -- Optional invariant audit
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_canon_invariant') THEN
      v_incons := rbac.count_canon_inconsistencies();
      PERFORM rbac.log_canon_invariant(v_incons, (v_incons = 0), 'after_run');
    END IF;
    -- Optional batch-level log (idempotent)
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'log_batch_run') THEN
      PERFORM rbac.log_batch_run(batch_size, total_updated, 'completed', details_json);
    END IF;
    RAISE NOTICE 'rbac.canonicalize_all finished: updated_rows=%', total_updated;
    -- Update circuit breaker on success
    PERFORM rbac.update_canon_circuit_breaker(TRUE);
  EXCEPTION WHEN OTHERS THEN
    -- Update circuit breaker on failure
    PERFORM rbac.update_canon_circuit_breaker(FALSE);
    -- Ensure the lock is released on error before propagating
    PERFORM pg_advisory_unlock(123456789);
    RAISE;
  END;
  PERFORM pg_advisory_unlock(123456789);
END;
$$ LANGUAGE plpgsql;
