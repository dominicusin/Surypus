-- V402__rbac_canon_queue_broker_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'broker_run_once') THEN
    PERFORM rbac.broker_run_once(2);
  END IF;
END;
$$ LANGUAGE plpgsql;
