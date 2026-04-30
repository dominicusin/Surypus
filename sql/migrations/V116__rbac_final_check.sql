-- RBAC final check: verify core RBAC functions exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'guard_inventory_write_v2') THEN
    RAISE NOTICE 'RBAC FINAL CHECK: guard_inventory_write_v2 missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_permission_compat') THEN
    RAISE NOTICE 'RBAC FINAL CHECK: has_permission_compat missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'tenant_create_partition') THEN
    RAISE NOTICE 'RBAC FINAL CHECK: tenant_create_partition missing';
  END IF;
END $$;
