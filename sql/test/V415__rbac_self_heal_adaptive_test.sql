-- V415__rbac_self_heal_adaptive_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_adaptive') THEN
    PERFORM rbac.self_heal_adaptive();
  END IF;
END;
$$ LANGUAGE plpgsql;
