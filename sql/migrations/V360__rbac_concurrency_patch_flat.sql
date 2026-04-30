-- V360__rbac_concurrency_patch_flat.sql
-- Lightweight concurrency helpers for tests
CREATE OR REPLACE FUNCTION rbac.start_concurrency_session(_slot BIGINT) RETURNS BOOLEAN AS $$
BEGIN
  RETURN pg_try_advisory_lock(_slot);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac.end_concurrency_session(_slot BIGINT) RETURNS VOID AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_locks WHERE locktype = 'advisory' AND objid = _slot) THEN
    PERFORM pg_advisory_unlock(_slot);
  END IF;
END;
$$ LANGUAGE plpgsql;
