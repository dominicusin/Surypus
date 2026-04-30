-- Phase 6.1.1: Basic RBAC API consistency verification
CREATE OR REPLACE FUNCTION verify_rbac_api_consistency()
RETURNS BOOLEAN AS $$
DECLARE
  v1 BOOLEAN;
  v2 BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'has_permission_compat') INTO v1;
  SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'guard_inventory_write_v2') INTO v2;
  RETURN v1 AND v2;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN IF NOT verify_rbac_api_consistency() THEN RAISE EXCEPTION 'RBAC API inconsistency: has_permission_compat or guard_inventory_write_v2 missing'; END IF; END $$;
