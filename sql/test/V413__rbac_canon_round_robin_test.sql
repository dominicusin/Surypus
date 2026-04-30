-- V413__rbac_canon_round_robin_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'next_canon_table_round_robin') THEN
    PERFORM rbac.next_canon_table_round_robin();
  END IF;
END;
$$ LANGUAGE plpgsql;
