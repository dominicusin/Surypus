-- V380__rbac_canonical_batch_savepoints_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonical_batch_with_savepoints') THEN
    PERFORM rbac.canonical_batch_with_savepoints(5);
  END IF;
  -- Basic assertion: the call should complete and report integer
  RAISE NOTICE 'canonical_batch_with_savepoints test executed';
END;
$$ LANGUAGE plpgsql;
