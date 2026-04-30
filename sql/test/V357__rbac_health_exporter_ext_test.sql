-- V357__rbac_health_exporter_ext_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'export_canon_health') THEN
    PERFORM rbac.export_canon_health();
  END IF;
END;
$$ LANGUAGE plpgsql;
