-- V371__rbac_concurrency_scope_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'set_concurrency_scope') THEN
    PERFORM rbac.set_concurrency_scope('slotA,slotB');
  END IF;
END;
$$ LANGUAGE plpgsql;
