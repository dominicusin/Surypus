-- Phase 6.1: Simple wrapper to unify guard entry point for inventory writes
CREATE OR REPLACE FUNCTION guard_inventory_write(
  p_user_id UUID,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  -- Delegate to the canonical guard implementation
  RETURN guard_inventory_write_v2(p_user_id, p_tenant_id);
END;
$$ LANGUAGE plpgsql;
