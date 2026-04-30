-- Monitoring and observability foundation
-- Create basic metrics store and helper to record metrics
CREATE TABLE IF NOT EXISTS monitoring_metrics (
  id BIGSERIAL PRIMARY KEY,
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION record_metric(
  p_name TEXT,
  p_value NUMERIC
) RETURNS VOID AS $$
BEGIN
  INSERT INTO monitoring_metrics (metric_name, metric_value) VALUES (p_name, p_value);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION system_health_snapshot()
RETURNS JSONB AS $$
DECLARE
  v_count INT;
  v_json JSONB := '{}'::JSONB;
BEGIN
  SELECT 1 INTO v_count; -- placeholder for health checks
  v_json := jsonb_build_object('healthy', TRUE, 'checks', v_count);
  RETURN v_json;
END;
$$ LANGUAGE plpgsql;
