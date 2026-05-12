-- Migration V431: Consolidated RBAC metrics logging
-- Original files: V431__rbac_metrics_log_function.sql, V431__rbac_metrics_log_table.sql

-- Metrics log table
CREATE TABLE IF NOT EXISTS rbac_metrics_log (
    id SERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Metrics log function
CREATE OR REPLACE FUNCTION log_rbac_metric(name TEXT, value NUMERIC)
RETURNS VOID AS $$
BEGIN
    INSERT INTO rbac_metrics_log (metric_name, metric_value) VALUES (name, value);
END;
$$ LANGUAGE plpgsql;
