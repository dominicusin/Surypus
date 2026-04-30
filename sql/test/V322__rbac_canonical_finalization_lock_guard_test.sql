-- V322__rbac_canonical_finalization_lock_guard_test.sql
-- Basic test to call run_canon_with_lock()
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'run_canon_with_lock') THEN
    PERFORM rbac.run_canon_with_lock();
  END IF;
END;
$$ LANGUAGE plpgsql;
