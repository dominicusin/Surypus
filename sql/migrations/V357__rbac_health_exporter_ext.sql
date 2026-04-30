-- V357__rbac_health_exporter_ext.sql
-- Extend health export with a dedicated exporter for dashboards
CREATE OR REPLACE FUNCTION rbac.export_canon_health() RETURNS TEXT AS $$
BEGIN
  -- Emit health JSON via NOTIFY (for example, in CI integrations)
  PERFORM pg_notify('rbac_health_dashboard', rbac.health_dashboard_json()::text);
  RETURN 'exported';
END;
$$ LANGUAGE plpgsql;
