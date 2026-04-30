-- V328__rbac_canonical_finalization_batch_status.sql
-- Create batch status tracking for canonicalization runs
CREATE TABLE IF NOT EXISTS rbac.canon_batch_runs (
  id BIGSERIAL PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  batch_size INTEGER,
  total_updated INTEGER,
  status TEXT,
  details JSONB
);

CREATE OR REPLACE FUNCTION rbac.log_batch_run(_batch_size INTEGER, _total_updated INTEGER, _status TEXT, _details JSONB)
  RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.canon_batch_runs (started_at, ended_at, batch_size, total_updated, status, details)
  VALUES (NOW(), NULL, _batch_size, _total_updated, _status, _details);
END;
$$ LANGUAGE plpgsql;
