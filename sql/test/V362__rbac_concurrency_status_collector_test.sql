-- V362__rbac_concurrency_status_collector_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'collect_concurrency_status') THEN
    PERFORM rbac.collect_concurrency_status();
  END IF;
END;
$$ LANGUAGE plpgsql;
