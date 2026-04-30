-- V429__rbac_snapshot_progress_view2.sql
-- Extend snapshot progress view with more fields
CREATE OR REPLACE VIEW rbac.vw_canon_progress_enhanced AS
SELECT * FROM rbac.vw_canon_progress;
