-- V366__rbac_concurrency_rate_limit_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_rate_limited') THEN
    PERFORM rbac.canonicalize_all_rate_limited();
  END IF;
END;
$$ LANGUAGE plpgsql;
