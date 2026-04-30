-- V387__rbac_canon_progress_view.sql
-- Simple view that exposes the latest canonicalization progress as JSON
CREATE OR REPLACE VIEW rbac.vw_canon_progress AS
SELECT rbac.canon_progress() AS progress_json;
