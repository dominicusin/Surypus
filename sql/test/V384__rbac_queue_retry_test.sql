-- V384__rbac_queue_retry_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'retry_canon_queue_failed') THEN
    -- Initially set some rows to failed for test purposes
    IF EXISTS (SELECT 1 FROM rbac.canon_queue WHERE status = 'failed') THEN
      -- call retry
      PERFORM rbac.retry_canon_queue_failed();
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
