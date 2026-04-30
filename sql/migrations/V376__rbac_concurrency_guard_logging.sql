-- V376__rbac_concurrency_guard_logging.sql
-- Track lock contention attempts for canonicalization to aid debugging in prod
CREATE TABLE IF NOT EXISTS rbac.canon_lock_attempts (
  id BIGSERIAL PRIMARY KEY,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  slot BIGINT,
  schema_name TEXT,
  table_name TEXT,
  attempted BOOLEAN NOT NULL,
  success BOOLEAN,
  reason TEXT
);

CREATE OR REPLACE FUNCTION rbac.record_lock_attempt(
  _slot BIGINT,
  _schema TEXT,
  _table TEXT,
  _attempted BOOLEAN,
  _success BOOLEAN,
  _reason TEXT
) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.canon_lock_attempts(slot, schema_name, table_name, attempted, success, reason)
  VALUES (_slot, _schema, _table, _attempted, _success, _reason);
END;
$$ LANGUAGE plpgsql;
