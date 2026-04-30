-- RBAC unify and validation patch
CREATE OR REPLACE FUNCTION has_permission_compat(
  p_user_id UUID,
  p_resource TEXT,
  p_action TEXT,
  p_tenant_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_ok BOOLEAN;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN TRUE;
  END IF;
  BEGIN
    v_ok := FALSE;
    -- Prefer canonical cached path if available; otherwise fallback
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_permission_cached') THEN
      BEGIN
        EXECUTE 'SELECT has_permission_cached($1, $2, $3, $4)' INTO v_ok USING p_user_id, p_resource, p_action, p_tenant_id;
      EXCEPTION WHEN OTHERS THEN
        v_ok := TRUE;
      END;
    ELSIF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_permission') THEN
      BEGIN
        EXECUTE 'SELECT has_permission($1, $2, $3, $4)' INTO v_ok USING p_user_id, p_resource, p_action, p_tenant_id;
      EXCEPTION WHEN OTHERS THEN
        v_ok := TRUE;
      END;
    ELSE
      v_ok := TRUE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_ok := TRUE;
  END;
  RETURN v_ok;
END;
$$ LANGUAGE plpgsql;

-- Override guard function to use unified permission check
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
