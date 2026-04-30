-- V453__rbac_round_robin_integration_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='rbac' AND routine_name='canonize_next_via_rr') THEN
    PERFORM rbac.canonize_next_via_rr();
  END IF;
END;
$$ LANGUAGE plpgsql;
