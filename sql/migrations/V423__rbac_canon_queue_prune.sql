-- V423__rbac_canon_queue_prune.sql
-- Prune completed items older than a retention window in canon_queue
DO $$
DECLARE
  _cut TIMESTAMPTZ := NOW() - INTERVAL '30 days';
BEGIN
  DELETE FROM rbac.canon_queue WHERE status = 'completed' AND enqueued_at < _cut;
END;
$$ LANGUAGE plpgsql;
