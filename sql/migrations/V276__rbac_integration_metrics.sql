-- Phase 6b: RBAC observability metrics
CREATE TABLE IF NOT EXISTS rbac_metrics (
  id BIGSERIAL PRIMARY KEY,
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION record_rbac_metric(
  p_metric_name TEXT,
  p_value NUMERIC
) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac_metrics (metric_name, metric_value) VALUES (p_metric_name, p_value);
END;
$$ LANGUAGE plpgsql;
