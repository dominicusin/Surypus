-- V395__rbac_prometheus_extension.sql
-- Extend Prometheus metrics with extra gauge for backlog
DO $$BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_backlog' AND indexname = 'idx_can_backlog') THEN
    -- a lightweight stub for backlog metric index (no real data required)
    CREATE TABLE IF NOT EXISTS rbac.canon_backlog (
      id BIGSERIAL PRIMARY KEY,
      backlog_count INT NOT NULL DEFAULT 0
    );
  END IF;
END;
$$ LANGUAGE plpgsql;
