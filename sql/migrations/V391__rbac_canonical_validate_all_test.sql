-- V391__rbac_canonical_validate_all_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'validate_all_can_paths') THEN
    PERFORM rbac.validate_all_can_paths();
  END IF;
END;
$$ LANGUAGE plpgsql;
