-- V350__rbac_canon_dashboard_notify.sql
-- Notify current canonicalization health to external systems (CI/monitoring)
CREATE OR REPLACE FUNCTION rbac.notify_canon_health_dashboard() RETURNS VOID AS $$
DECLARE
  v_health JSONB;
BEGIN
  v_health := rbac.canon_health_detailed();
  IF v_health IS NOT NULL THEN
    PERFORM pg_notify('rbac_canon_health', v_health::text);
  END IF;
END;
$$ LANGUAGE plpgsql;
