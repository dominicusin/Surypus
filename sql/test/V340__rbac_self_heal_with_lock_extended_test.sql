-- V340__rbac_self_heal_with_lock_extended_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_with_lock') THEN
    PERFORM rbac.self_heal_with_lock();
  END IF;
END;
$$ LANGUAGE plpgsql;
