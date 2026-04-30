-- V324__rbac_canonical_finalization_cleanup_test.sql
-- Ensure purge_old_canon_metrics can be executed without error
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'purge_old_canon_metrics') THEN
    PERFORM rbac.purge_old_canon_metrics(30);
  END IF;
END;
$$ LANGUAGE plpgsql;
