-- V384__rbac_queue_retry.sql
-- Retry mechanism for failed canonicalization queue entries
CREATE OR REPLACE FUNCTION rbac.retry_canon_queue_failed() RETURNS INTEGER AS $$
DECLARE
  updated INTEGER := 0;
BEGIN
  UPDATE rbac.canon_queue
  SET status = 'pending', enqueued_at = NOW(), updated_count = NULL, error_message = NULL
  WHERE status = 'failed';
  GET DIAGNOSTICS updated = ROW_COUNT;
  RETURN COALESCE(updated, 0);
END;
$$ LANGUAGE plpgsql;
