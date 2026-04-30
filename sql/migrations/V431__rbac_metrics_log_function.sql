-- V431__rbac_metrics_log_function.sql
CREATE OR REPLACE FUNCTION rbac.log_metric(_kind TEXT, _payload JSONB) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.metrics_log (kind, payload) VALUES (_kind, _payload);
END;
$$ LANGUAGE plpgsql;
