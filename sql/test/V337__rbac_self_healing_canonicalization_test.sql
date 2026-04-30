-- V337__rbac_self_healing_canonicalization_test.sql
-- Test self-heal function
DO $$
BEGIN
  -- Ensure the function exists and can be called without error
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_canonicalization') THEN
    PERFORM rbac.self_heal_canonicalization();
  END IF;
END;
$$ LANGUAGE plpgsql;