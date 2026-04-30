-- V403__rbac_canon_priority_sort.sql
-- Ensure the canonical queue dequeue uses priority ordering when selecting items
CREATE OR REPLACE FUNCTION rbac.dequeue_canon_batch_priority(_limit INT) RETURNS TABLE (id BIGINT, table_schema TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT id, table_schema, table_name
  FROM rbac.canon_queue
  WHERE status = 'pending'
  ORDER BY priority DESC NULLS LAST, enqueued_at ASC
  LIMIT COALESCE(_limit, 10);
END;
$$ LANGUAGE plpgsql;
