-- V420__rbac_concurrency_backlog_metrics_ext_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'collect_backlog_metrics') THEN
    PERFORM rbac.collect_backlog_metrics();
  END IF;
END;
$$ LANGUAGE plpgsql;
