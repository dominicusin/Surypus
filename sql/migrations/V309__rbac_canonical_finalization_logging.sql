-- V309__rbac_canonical_finalization_logging.sql
-- Create a simple log for canonicalization runs to aid observability.
-- Ensure the rbac schema exists (idempotent).
CREATE SCHEMA IF NOT EXISTS rbac;

DO $$
BEGIN
  -- Create log table if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'rbac' AND table_name = 'canon_log'
  ) THEN
    EXECUTE 'CREATE TABLE rbac.canon_log (
      id BIGSERIAL PRIMARY KEY,
      run_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      note TEXT
    )';
  END IF;
  -- Insert a simple log entry for this migration run
  EXECUTE 'INSERT INTO rbac.canon_log (note) VALUES (''RBAC canonicalization run'')';
END;
$$ LANGUAGE plpgsql;
