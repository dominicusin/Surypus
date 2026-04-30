-- V427__rbac_concurrency_guarded_run.sql
-- Guarded canonicalization run using can_run_canon
CREATE OR REPLACE FUNCTION rbac.run_concurrency_guarded() RETURNS VOID AS $$
BEGIN
  IF rbac.can_run_canon() THEN
    PERFORM rbac.canonicalize_all();
  ELSE
    RAISE NOTICE 'rbac.run_concurrency_guarded: blocked by gate';
  END IF;
END;
$$ LANGUAGE plpgsql;
