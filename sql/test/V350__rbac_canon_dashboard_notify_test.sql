-- V350__rbac_canon_dashboard_notify_test.sql
-- Basic sanity: ensure the function can be invoked without error
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'notify_canon_health_dashboard') THEN
    PERFORM rbac.notify_canon_health_dashboard();
  END IF;
END;
$$ LANGUAGE plpgsql;
