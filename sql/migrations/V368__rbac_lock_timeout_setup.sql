-- V368__rbac_lock_timeout_setup.sql
-- Introduce a per-session advisory lock timeout helper for kanonization
CREATE OR REPLACE FUNCTION rbac.set_canon_lock_timeout(_ms INTEGER) RETURNS VOID AS $$
BEGIN
  IF _ms IS NULL THEN
    RAISE NOTICE 'Canon lock timeout set to default (no-op)';
  ELSE
    EXECUTE format('SET LOCAL lock_timeout = %s', _ms);
  END IF;
END;
$$ LANGUAGE plpgsql;
