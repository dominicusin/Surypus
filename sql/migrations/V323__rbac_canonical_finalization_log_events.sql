-- V323__rbac_canonical_finalization_log_events.sql
-- Create canon event log table and log function
CREATE OR REPLACE FUNCTION rbac.log_canon_event(table_schema TEXT, table_name TEXT, updated INT)
  RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.canon_events (table_schema, table_name, updated)
  VALUES (table_schema, table_name, COALESCE(updated,0));
END;
$$ LANGUAGE plpgsql;

-- Create canon_events table if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'rbac' AND table_name = 'canon_events'
  ) THEN
    EXECUTE 'CREATE TABLE rbac.canon_events (
      id BIGSERIAL PRIMARY KEY,
      run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      table_schema TEXT,
      table_name TEXT,
      updated INT
    )';
  END IF;
END;
$$ LANGUAGE plpgsql;
