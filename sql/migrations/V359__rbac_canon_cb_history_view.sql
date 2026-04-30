-- V359__rbac_canon_cb_history_view.sql
-- Create a simple view to surface recent circuit-breaker transitions
CREATE OR REPLACE VIEW rbac.vw_canon_cb_history AS
SELECT id, created_at, old_state, new_state, details
FROM rbac.canon_cb_history
ORDER BY created_at DESC
LIMIT 100;
