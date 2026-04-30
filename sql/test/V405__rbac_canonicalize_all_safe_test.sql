-- V405__rbac_canonicalize_all_safe_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_all_safe') THEN
    PERFORM rbac.canonicalize_all_safe();
  END IF;
END;
$$ LANGUAGE plpgsql;
