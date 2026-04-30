-- V394__rbac_alerting_integration_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'notify_external_alert') THEN
    PERFORM rbac.notify_external_alert('{"alert":"test"}'::jsonb);
  END IF;
END;
$$ LANGUAGE plpgsql;
