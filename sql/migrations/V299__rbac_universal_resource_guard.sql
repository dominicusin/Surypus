-- Phase 6.4: Universal resource guard for write operations
CREATE OR REPLACE FUNCTION guard_resource_write(
  p_resource TEXT,
  p_user_id UUID,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  IF NOT has_permission_compat(p_user_id, p_resource, 'write', p_tenant_id) THEN
    RAISE EXCEPTION 'Access denied: % write', p_resource;
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
