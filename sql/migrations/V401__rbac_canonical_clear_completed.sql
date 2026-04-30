-- V401__rbac_canonical_clear_completed.sql
-- Purge completed canonical queue rows older than a given number of days
CREATE OR REPLACE FUNCTION rbac.purge_completed_canon_queue(_older_days INTEGER DEFAULT 30) RETURNS INTEGER AS $$
DECLARE
  _cut TIMESTAMPTZ := NOW() - (INTERVAL '1 day' * _older_days);
  _deleted INTEGER;
BEGIN
  DELETE FROM rbac.canon_queue
  WHERE status = 'completed'
    AND enqueued_at < _cut;
  GET DIAGNOSTICS _deleted = ROW_COUNT;
  RETURN _deleted;
END;
$$ LANGUAGE plpgsql;
