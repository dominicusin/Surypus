-- Phase 6.9: Runtime sanity check for RBAC wiring
DO $$ BEGIN
  BEGIN
    IF NOT (SELECT validate_rbac_and_projection_ready()) THEN
      RAISE NOTICE 'RBAC wiring sanity check failed';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'RBAC wiring sanity evaluation threw an exception';
  END;
END $$;
