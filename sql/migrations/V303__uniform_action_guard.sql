-- Phase 6.5.1: Uniform action guard for resources
CREATE OR REPLACE FUNCTION permission_guard(
  p_user_id UUID,
  p_tenant_id UUID,
  p_resource TEXT,
  p_action TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  RETURN has_permission_compat(p_user_id, p_resource, p_action, p_tenant_id);
END;
$$ LANGUAGE plpgsql;
