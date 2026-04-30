-- V399__rbac_canon_dequeue_with_priority.sql
-- Dequeue batch by priority (for testing in queue workers)
CREATE OR REPLACE FUNCTION rbac.dequeue_canon_batch_priority(_limit INT) RETURNS TABLE (id BIGINT, schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT id, schema_name, table_name
  FROM rbac.canon_queue
  WHERE status = 'pending'
  ORDER BY priority DESC, enqueued_at ASC
  LIMIT COALESCE(_limit, 10);
END;
$$ LANGUAGE plpgsql;
