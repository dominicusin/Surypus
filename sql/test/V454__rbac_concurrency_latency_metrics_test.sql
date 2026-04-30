-- V454__rbac_concurrency_latency_metrics_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'collect_latency_metrics') THEN
    PERFORM rbac.collect_latency_metrics();
  END IF;
END;
$$ LANGUAGE plpgsql;
