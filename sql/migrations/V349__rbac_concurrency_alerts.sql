-- V349__rbac_concurrency_alerts.sql
-- Trigger or alert hooks for concurrency events (placeholder for CI alerts)
CREATE OR REPLACE FUNCTION rbac.canon_concurrency_alert(_msg TEXT) RETURNS VOID AS $$
BEGIN
  -- In CI, push alert to external system; here we log a notice for visibility
  RAISE NOTICE 'CANCONC_ALERT: %', _msg;
  -- Optional: also push to an external notifier if configured
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'notify_external_alert') THEN
    PERFORM rbac.notify_external_alert(jsonb_build_object('type','concurrency','msg', _msg));
  END IF;
END;
$$ LANGUAGE plpgsql;
