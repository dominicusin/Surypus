-- V432__rbac_metrics_log_view.sql
CREATE OR REPLACE VIEW rbac.vw_metrics_log AS
SELECT id, metric_name, metric_value, recorded_at
FROM rbac_metrics_log
ORDER BY recorded_at DESC
LIMIT 100;
