-- V388__rbac_concurrency_backlog_alerts_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'backlog_alerts') THEN
    PERFORM rbac.backlog_alerts();
  END IF;
END;
$$ LANGUAGE plpgsql;
