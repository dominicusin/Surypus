-- V360__rbac_concurrency_patch_flat_test.sql
DO $$
DECLARE
  s1 BOOLEAN;
  s2 BOOLEAN;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'start_concurrency_session') THEN
    s1 := rbac.start_concurrency_session(987654321);
    s2 := rbac.start_concurrency_session(987654322);
    -- release if acquired
    IF s1 THEN PERFORM rbac.end_concurrency_session(987654321); END IF;
    IF s2 THEN PERFORM rbac.end_concurrency_session(987654322); END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
