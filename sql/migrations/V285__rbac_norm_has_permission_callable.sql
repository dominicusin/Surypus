-- Phase 6.5: Normalization of has_permission callable (canonical entry point)
DROP FUNCTION IF EXISTS has_permission(UUID, TEXT, TEXT, UUID);
CREATE OR REPLACE FUNCTION has_permission(
  p_user_id UUID,
  p_resource TEXT,
  p_action TEXT,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN has_permission_compat(p_user_id, p_resource, p_action, p_tenant_id);
END;
$$ LANGUAGE plpgsql;
