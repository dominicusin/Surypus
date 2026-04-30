-- V351__rbac_concurrency_executor_test.sql
-- Basic concurrency executor invocation test
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'concurrent_canon_job') THEN
    PERFORM rbac.concurrent_canon_job(123456789);
  END IF;
END;
$$ LANGUAGE plpgsql;
