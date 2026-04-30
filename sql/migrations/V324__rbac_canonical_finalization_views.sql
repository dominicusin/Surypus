-- V324__rbac_canonical_finalization_views.sql
-- Create a view to summarize latest canonicalization runs
CREATE OR REPLACE VIEW rbac.view_canon_summary AS
SELECT id, run_at, updated_rows, details
FROM rbac.canon_metrics
ORDER BY run_at DESC
LIMIT 20;
