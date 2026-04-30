-- V368__rbac_lock_timeout_setup_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'set_canon_lock_timeout') THEN
    PERFORM rbac.set_canon_lock_timeout(500);
  END IF;
END;
$$ LANGUAGE plpgsql;
