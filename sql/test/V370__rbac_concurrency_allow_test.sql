-- V370__rbac_concurrency_allow_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'set_concurrency_allowed') THEN
    PERFORM rbac.set_concurrency_allowed(true);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'set_concurrency_allowed') THEN
    PERFORM rbac.set_concurrency_allowed(false);
  END IF;
END;
$$ LANGUAGE plpgsql;
