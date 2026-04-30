-- RBAC: permission cache table for has_permission_cached
CREATE TABLE IF NOT EXISTS rbac_permission_cache (
  user_id UUID NOT NULL,
  resource TEXT NOT NULL,
  action TEXT NOT NULL,
  tenant_id UUID NOT NULL,
  has_perm BOOLEAN NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, resource, action, tenant_id)
);

CREATE OR REPLACE FUNCTION has_permission_cached(
  p_user_id UUID,
  p_resource TEXT,
  p_action TEXT,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_perm BOOLEAN;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  IF EXISTS (SELECT 1 FROM rbac_permission_cache WHERE user_id = p_user_id AND resource = p_resource AND action = p_action AND tenant_id = p_tenant_id) THEN
    SELECT has_perm INTO v_perm FROM rbac_permission_cache WHERE user_id = p_user_id AND resource = p_resource AND action = p_action AND tenant_id = p_tenant_id;
    RETURN v_perm;
  END IF;
  v_perm := has_permission_compat(p_user_id, p_resource, p_action, p_tenant_id);
  INSERT INTO rbac_permission_cache (user_id, resource, action, tenant_id, has_perm, updated_at)
  VALUES (p_user_id, p_resource, p_action, p_tenant_id, v_perm, NOW())
  ON CONFLICT (user_id, resource, action, tenant_id) DO UPDATE SET has_perm = EXCLUDED.has_perm, updated_at = NOW();
  RETURN v_perm;
END;
$$ LANGUAGE plpgsql;
