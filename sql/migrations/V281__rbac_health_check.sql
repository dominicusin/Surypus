-- Phase 7: RBAC health check utility
CREATE OR REPLACE FUNCTION rbac_health_check()
RETURNS BOOLEAN AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_permission_compat') THEN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'guard_inventory_write_v2') THEN
      RETURN TRUE;
    END IF;
  END IF;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  IF NOT rbac_health_check() THEN
    RAISE NOTICE 'RBAC health check failed';
  ELSE
    RAISE NOTICE 'RBAC health check OK';
  END IF;
END $$;
