-- RBAC compatibility check (non-destructive)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rbac_dynamic_roles') THEN
    RAISE NOTICE 'RBAC: detected dynamic RBAC (rbac_dynamic_roles)';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rbac_schema') OR
     EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rbac_schema_permissions') THEN
    RAISE NOTICE 'RBAC: legacy RBAC schema detected';
  END IF;
END $$;
