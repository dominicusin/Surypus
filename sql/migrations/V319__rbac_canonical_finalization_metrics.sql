-- V319__rbac_canonical_finalization_metrics.sql
-- Create canonicalization metrics table and log function
CREATE OR REPLACE FUNCTION rbac.log_canon_metrics(updated_rows INTEGER, details JSONB)
  RETURNS VOID AS $$
BEGIN
  IF updated_rows IS NULL THEN
    updated_rows := 0;
  END IF;
  INSERT INTO rbac.canon_metrics (updated_rows, details)
  VALUES (updated_rows, details);
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  -- Create metrics table if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'rbac' AND table_name = 'canon_metrics'
  ) THEN
    EXECUTE 'CREATE TABLE rbac.canon_metrics (
      id BIGSERIAL PRIMARY KEY,
      run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_rows INT NOT NULL,
      details JSONB
    )';
  END IF;
END;
$$ LANGUAGE plpgsql;
