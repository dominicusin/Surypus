-- V338__rbac_canonical_finalization_safe_wrapper.sql
-- Safe wrapper for canonicalization to respect circuit breaker state
CREATE OR REPLACE FUNCTION rbac.safe_canonicalize_all()
RETURNS VOID AS $$
BEGIN
  IF rbac.check_canon_circuit_breaker() THEN
    -- Use the canonicalize_all() path which includes locking and logging
    PERFORM rbac.canonicalize_all();
  ELSE
    RAISE NOTICE 'rbac.safe_canonicalize_all: circuit breaker OPEN, skipping canonicalization';
  END IF;
END;
$$ LANGUAGE plpgsql;
