-- V422__rbac_prometheus_priority_metrics_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'prometheus_priority_metrics') THEN
    PERFORM rbac.prometheus_priority_metrics();
  END IF;
END;
$$ LANGUAGE plpgsql;
