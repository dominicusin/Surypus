-- V351__rbac_concurrency_executor.sql
-- Concurrency wrapper for canonicalization: run under advisory lock to simulate concurrent runs
CREATE OR REPLACE FUNCTION rbac.concurrent_canon_job(_slot BIGINT DEFAULT 123456789)
RETURNS BOOLEAN AS $$
DECLARE
  acquired BOOLEAN;
BEGIN
  acquired := pg_try_advisory_lock(_slot);
  IF NOT acquired THEN
    -- Could not acquire lock; simulate that another process is running
    RETURN FALSE;
  END IF;

  BEGIN
    -- Run canonicalization logic; rely on existing locking inside canonicalize_all()
    PERFORM rbac.canonicalize_all();
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(_slot);
    RAISE;
  END;

  PERFORM pg_advisory_unlock(_slot);
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
