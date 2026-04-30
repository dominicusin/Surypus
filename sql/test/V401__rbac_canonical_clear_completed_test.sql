-- V401__rbac_canonical_clear_completed_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'purge_completed_canon_queue') THEN
    PERFORM rbac.purge_completed_canon_queue(30);
  END IF;
END;
$$ LANGUAGE plpgsql;
