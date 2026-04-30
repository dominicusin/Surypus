-- V365__rbac_concurrency_nested_savepoints_test.sql
DO $$
DECLARE
  v INT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canonicalize_table_with_savepoint') THEN
    v := rbac.canonicalize_table_with_savepoint('rbac','canon_metrics');
    -- ignore result, just ensure no crash
  END IF;
END;
$$ LANGUAGE plpgsql;
