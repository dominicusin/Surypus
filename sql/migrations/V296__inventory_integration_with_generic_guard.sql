-- Phase 6.1.1b: Demonstrative integration of generic write guard in inventory
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'guard_write_generic') THEN
    RAISE NOTICE 'Generic write guard is available for inventory integration';
  END IF;
END $$;
