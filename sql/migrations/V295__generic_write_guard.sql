-- Generic RBAC guard: supports multiple resources via a single entrypoint
CREATE OR REPLACE FUNCTION guard_write_generic(
  p_resource TEXT,
  p_user_id UUID,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  RETURN has_permission_compat(p_user_id, p_resource, 'write', p_tenant_id);
END;
$$ LANGUAGE plpgsql;
