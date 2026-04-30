-- V455__rbac_backlog_skew_alerts_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='rbac' AND routine_name='backlog_skew_alert') THEN
    PERFORM rbac.backlog_skew_alert(20);
  END IF;
END;
$$ LANGUAGE plpgsql;
