-- V405__rbac_canonicalize_all_safe.sql
-- Safe wrapper for canonicalize_all with circuit-breaker gating
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_safe() RETURNS VOID AS $$
BEGIN
  IF rbac.can_run_canon() THEN
    PERFORM rbac.canonicalize_all();
  ELSE
    RAISE NOTICE 'rbac.canonicalize_all_safe: skip due to can_run=false or backlog';
  END IF;
END;
$$ LANGUAGE plpgsql;
