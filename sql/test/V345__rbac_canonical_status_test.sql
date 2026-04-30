-- V345__rbac_canonical_status_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_status') THEN
    RAISE NOTICE '%', rbac.canon_status();
  END IF;
END;
$$ LANGUAGE plpgsql;
