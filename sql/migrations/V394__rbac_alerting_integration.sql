-- V394__rbac_alerting_integration.sql
-- Extend alerting integration by exposing a channel-based external alert function
CREATE OR REPLACE FUNCTION rbac.notify_external_alert(_payload JSONB) RETURNS VOID AS $$
BEGIN
  IF _payload IS NULL THEN
    RETURN;
  END IF;
  -- Use NOTIFY to publish to external listeners (e.g. CI observability layer, alert system)
  PERFORM pg_notify('rbac_alert', _payload::TEXT);
END;
$$ LANGUAGE plpgsql;
