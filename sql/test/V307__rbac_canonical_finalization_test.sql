-- V307__rbac_canonical_finalization_test.sql
-- Smoke test to ensure the canonicalization entrypoint exists and runs.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.routines
    WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_wrappers'
  ) THEN
    RAISE EXCEPTION 'rbac.canonicalize_wrappers function not found';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Execute to ensure the canonicalization can run without error.
PERFORM rbac.canonicalize_wrappers();
