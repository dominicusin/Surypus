-- V431__rbac_metrics_log_table.sql
-- Simple metrics log table for generalized metrics events
CREATE TABLE IF NOT EXISTS rbac.metrics_log (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  kind TEXT NOT NULL,
  payload JSONB
);
