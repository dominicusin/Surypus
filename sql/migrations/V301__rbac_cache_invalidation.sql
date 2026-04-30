-- Phase 6.5: Invalidate RBAC permission cache for a specific user/resource
CREATE OR REPLACE FUNCTION invalidate_permission_cache(
  p_user_id UUID,
  p_resource TEXT,
  p_tenant_id UUID
) RETURNS VOID AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;
  DELETE FROM rbac_permission_cache
  WHERE user_id = p_user_id AND resource = p_resource AND tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;
