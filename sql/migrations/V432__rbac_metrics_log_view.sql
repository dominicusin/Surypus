-- V432__rbac_metrics_log_view.sql
CREATE OR REPLACE VIEW rbac.vw_metrics_log AS
SELECT id, ts, kind, payload
FROM rbac.metrics_log
ORDER BY ts DESC
LIMIT 100;
