-- V451__rbac_canon_dequeue_next_table_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'dequeue_next_can_table') THEN
    PERFORM rbac.dequeue_next_can_table();
  END IF;
END;
$$ LANGUAGE plpgsql;
