-- V353__rbac_self_heal_advanced_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_advanced') THEN
    PERFORM rbac.self_heal_advanced();
  END IF;
END;
$$ LANGUAGE plpgsql;
