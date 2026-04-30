-- V402__rbac_canon_queue_broker.sql
-- A lightweight broker to process canon_queue entries in batches
CREATE OR REPLACE FUNCTION rbac.broker_run_once(_limit INTEGER DEFAULT 10) RETURNS INTEGER AS $$
DECLARE
  rec RECORD;
  processed INTEGER := 0;
BEGIN
  FOR rec IN (
    SELECT id, table_schema, table_name
    FROM rbac.canon_queue
    WHERE status = 'pending'
    ORDER BY priority DESC NULLS LAST, enqueued_at ASC
    LIMIT COALESCE(_limit, 10)
    FOR UPDATE SKIP LOCKED
  ) LOOP
    -- mark in-progress
    UPDATE rbac.canon_queue SET status = 'in_progress', started_at = NOW() WHERE id = rec.id;
    BEGIN
      -- perform per-table canonicalization
      PERFORM rbac.canonicalize_table(rec.table_schema, rec.table_name);
      -- mark completed
      UPDATE rbac.canon_queue SET status = 'completed', finished_at = NOW() WHERE id = rec.id;
    EXCEPTION WHEN OTHERS THEN
      UPDATE rbac.canon_queue SET status = 'failed', error_message = SQLERRM WHERE id = rec.id;
    END;
    processed := processed + 1;
  END LOOP;
  RETURN processed;
END;
$$ LANGUAGE plpgsql;
