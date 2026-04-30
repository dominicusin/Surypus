-- Canonical RBAC safeguard utilities for inventory and projection paths
CREATE OR REPLACE FUNCTION rbac_access_guard(
  p_user_id UUID,
  p_tenant_id UUID,
  p_action TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  RETURN has_permission_compat(p_user_id, 'Inventory', p_action, p_tenant_id);
END;
$$ LANGUAGE plpgsql;
