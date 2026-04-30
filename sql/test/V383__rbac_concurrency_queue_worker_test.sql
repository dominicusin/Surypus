-- V383__rbac_concurrency_queue_worker_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'run_canon_queue_worker') THEN
    PERFORM rbac.run_canon_queue_worker(5);
  END IF;
END;
$$ LANGUAGE plpgsql;
