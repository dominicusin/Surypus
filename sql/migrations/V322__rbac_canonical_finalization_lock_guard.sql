-- V322__rbac_canonical_finalization_lock_guard.sql
-- Guard canonicalization with advisory lock using non-blocking try lock
CREATE OR REPLACE FUNCTION rbac.run_canon_with_lock() RETURNS VOID AS $$
DECLARE
  acquired BOOLEAN;
BEGIN
  acquired := pg_try_advisory_lock(123456789);
  IF NOT acquired THEN
    RAISE NOTICE 'rbac.run_canon_with_lock: canonicalization already running';
    RETURN;
  END IF;

  BEGIN
    -- Run the canonicalization routine under the lock
    PERFORM rbac.canonicalize_all();
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(123456789);
    RAISE;
  END;

  PERFORM pg_advisory_unlock(123456789);
END;
$$ LANGUAGE plpgsql;
