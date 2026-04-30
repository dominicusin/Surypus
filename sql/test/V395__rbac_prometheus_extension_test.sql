-- V395__rbac_prometheus_extension_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_health') THEN
    PERFORM rbac.canon_health();
  END IF;
END;
$$ LANGUAGE plpgsql;
