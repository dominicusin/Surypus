-- Phase 6c: Final unification of RBAC guard and safe checks
-- Re-create guard function to ensure canonical behavior across environments
DROP FUNCTION IF EXISTS guard_inventory_write_v2(p_user_id UUID, p_tenant_id UUID);
CREATE OR REPLACE FUNCTION guard_inventory_write_v2(
  p_user_id UUID,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  IF NOT has_permission_compat(p_user_id, 'inventory', 'write', p_tenant_id) THEN
    RAISE EXCEPTION 'Access denied: inventory_write required';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
