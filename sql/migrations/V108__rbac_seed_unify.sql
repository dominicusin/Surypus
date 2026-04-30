-- Non-destructive RBAC unification seed (safeguard)
DO $$ BEGIN
  -- If dynamic RBAC table exists, seed a canonical admin role if not present
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rbac_dynamic_roles') THEN
    BEGIN
      EXECUTE 'INSERT INTO rbac_dynamic_roles (name) SELECT ''admin'' WHERE NOT EXISTS (SELECT 1 FROM rbac_dynamic_roles WHERE name = ''admin'')';
    EXCEPTION WHEN OTHERS THEN
      -- Ignore if schema differs; this is a best-effort seed
      NULL;
    END;
  END IF;
END $$;
