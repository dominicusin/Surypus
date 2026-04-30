-- V452__rbac_canon_round_robin_step_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_round_robin_step') THEN
    PERFORM rbac.canon_round_robin_step();
  END IF;
END;
$$ LANGUAGE plpgsql;
