-- Final cleanup: unify has_permission wrapper if missing
DO $$
BEGIN
  IF NOT EXISTS (
     SELECT 1
     FROM pg_proc p
     JOIN pg_namespace n ON p.pronamespace = n.oid
     WHERE p.proname = 'has_permission' AND n.nspname = 'public'
  ) THEN
     EXECUTE 'CREATE OR REPLACE FUNCTION has_permission(p_user_id UUID, p_resource TEXT, p_action TEXT, p_tenant_id UUID) RETURNS BOOLEAN AS $function$ BEGIN RETURN has_permission_compat(p_user_id, p_resource, p_action, p_tenant_id); END; $function$ LANGUAGE plpgsql';
  END IF;
END
$$;
