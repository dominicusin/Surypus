-- V434__rbac_ci_integration_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='rbac' AND routine_name='ci_validate_migrations') THEN
    PERFORM rbac.ci_validate_migrations();
  END IF;
END;
$$ LANGUAGE plpgsql;
