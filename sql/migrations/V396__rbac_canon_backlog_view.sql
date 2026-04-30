-- V396__rbac_canon_backlog_view.sql
-- Create a view to summarize backlog across canon_queue
CREATE OR REPLACE VIEW rbac.vw_canon_backlog AS
SELECT table_schema, table_name, COUNT(*) AS backlog
FROM rbac.canon_queue
WHERE status = 'pending'
GROUP BY table_schema, table_name;
