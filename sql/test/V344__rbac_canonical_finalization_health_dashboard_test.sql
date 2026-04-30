-- V344__rbac_canonical_finalization_health_dashboard_test.sql
DO $$
DECLARE
  v_json JSONB;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'health_dashboard_json') THEN
    v_json := rbac.health_dashboard_json();
    IF v_json IS NULL THEN
      RAISE EXCEPTION 'health_dashboard_json returned NULL';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
