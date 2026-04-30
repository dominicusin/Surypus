-- V408__rbac_observability_dashboard_enhanced_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_rbac_canon_dashboard') THEN
    PERFORM 1;
  END IF;
END;
$$ LANGUAGE plpgsql;
