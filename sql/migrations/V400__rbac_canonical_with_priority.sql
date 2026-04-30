-- V400__rbac_canonical_with_priority.sql
-- Canonicalize queued items by priority in a controlled manner
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_with_priority(_limit INTEGER DEFAULT 10) RETURNS INTEGER AS $$
DECLARE
  rec RECORD;
  v_updated INTEGER := 0;
  v_schema TEXT;
  v_table TEXT;
  v_cnt INTEGER;
BEGIN
  -- Iterate over the queue with highest priority first
  FOR rec IN (
    SELECT id, table_schema, table_name
    FROM rbac.canon_queue
    WHERE status = 'pending'
    ORDER BY priority DESC, enqueued_at ASC
    LIMIT COALESCE(_limit, 10)
  ) LOOP
    v_schema := rec.table_schema;
    v_table := rec.table_name;
    BEGIN
      -- Canonicalize a single table; use existing per-table function when available
      PERFORM rbac.canonicalize_table(v_schema, v_table);
      UPDATE rbac.canon_queue SET status = 'completed', updated_count = 0 WHERE id = rec.id;
      v_updated := v_updated + 1;
    EXCEPTION WHEN OTHERS THEN
      UPDATE rbac.canon_queue SET status = 'failed', error_message = SQLERRM WHERE id = rec.id;
      v_updated := v_updated + 1;
    END;
  END LOOP;
  RETURN v_updated;
END;
$$ LANGUAGE plpgsql;
