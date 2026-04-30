-- V355__rbac_self_heal_policy_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'self_heal_policy') THEN
    PERFORM rbac.self_heal_policy();
  END IF;
  -- Post-condition: invariants should still hold
  IF NOT rbac.is_canonical_consistent() THEN
    RAISE EXCEPTION 'self_heal_policy test failed: invariants violated';
  END IF;
END;
$$ LANGUAGE plpgsql;
