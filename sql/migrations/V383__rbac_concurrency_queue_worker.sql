-- V383__rbac_concurrency_queue_worker.sql
-- Worker that runs a batch consumer on the canon_queue
CREATE OR REPLACE FUNCTION rbac.run_canon_queue_worker(_limit INT DEFAULT 10) RETURNS VOID AS $$
DECLARE
  n INT := 0;
  processed INT;
BEGIN
  processed := rbac.process_canon_queue_batch(_limit);
  IF processed > 0 THEN
    n := n + processed;
  END IF;
  RETURN;
END;
$$ LANGUAGE plpgsql;
