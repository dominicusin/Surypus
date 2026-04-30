-- RBAC Edge Cases: basic guards for null inputs and canonical calls
DO $$
DECLARE
  v BOOLEAN;
BEGIN
  -- Null user should be allowed (per test conventions)
  v := has_permission_compat(NULL, 'inventory', 'read', NULL);
  IF NOT v THEN
    RAISE EXCEPTION 'RBAC edge: null user should be allowed';
  END IF;
  RAISE NOTICE 'RBAC edge: NULL user check passed';
END;
$$ LANGUAGE plpgsql;
