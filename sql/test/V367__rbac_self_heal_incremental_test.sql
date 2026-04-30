-- V367__rbac_self_heal_incremental_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_incremental') THEN
    PERFORM rbac.self_heal_incremental(3);
  END IF;
END;
$$ LANGUAGE plpgsql;
