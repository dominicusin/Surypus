-- V408__rbac_observability_dashboard_enhanced.sql
-- Extend observability with a richer canonicalization progress view
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_rbac_canon_dashboard') THEN
    CREATE VIEW rbac.vw_rbac_canon_dashboard AS
    SELECT * FROM (SELECT * FROM rbac.vw_canon_progress) AS p;
  END IF;
END;
$$ LANGUAGE plpgsql;
