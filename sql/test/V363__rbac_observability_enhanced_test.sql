-- V363__rbac_observability_enhanced_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_health_detailed') THEN
    PERFORM rbac.canon_health_detailed();
  END IF;
END;
$$ LANGUAGE plpgsql;
