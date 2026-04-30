-- V371__rbac_concurrency_scope.sql
-- Define a concurrency scope for channeling canonicalization tasks
CREATE OR REPLACE FUNCTION rbac.set_concurrency_scope(_slots TEXT) RETURNS VOID AS $$
BEGIN
  -- store in config as a JSON string for simplicity
  PERFORM rbac.set_config_int('canonical_concurrency_scope', COALESCE(length(_slots), 0));
END;
$$ LANGUAGE plpgsql;
