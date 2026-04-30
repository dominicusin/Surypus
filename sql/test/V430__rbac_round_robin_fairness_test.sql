-- V430__rbac_round_robin_fairness_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'compute_round_robin_fairness') THEN
    PERFORM rbac.compute_round_robin_fairness();
  END IF;
END;
$$ LANGUAGE plpgsql;
