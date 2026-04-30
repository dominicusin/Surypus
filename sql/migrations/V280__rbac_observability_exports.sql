-- Phase 6d: Observability exports for RBAC
-- Exposes simple metrics about RBAC state for external observability dashboards
CREATE OR REPLACE FUNCTION export_rbac_metrics()
RETURNS VOID AS $$
DECLARE
  v_roles INT;
  v_perms INT;
BEGIN
  SELECT COUNT(*) INTO v_roles FROM roles;
  SELECT COUNT(*) INTO v_perms FROM permissions;
  PERFORM record_rbac_metric('rbac_roles', v_roles);
  PERFORM record_rbac_metric('rbac_permissions', v_perms);
END;
$$ LANGUAGE plpgsql;

-- Also provide a compact health signal for RBAC subsystem
CREATE OR REPLACE FUNCTION rbac_health_signal()
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object('roles', (SELECT COUNT(*) FROM roles), 'permissions', (SELECT COUNT(*) FROM permissions));
END;
$$ LANGUAGE plpgsql;
