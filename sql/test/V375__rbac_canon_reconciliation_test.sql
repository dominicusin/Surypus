-- V375__rbac_canon_reconciliation_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'get_canon_reconciliation') THEN
    PERFORM rbac.get_canon_reconciliation();
  END IF;
END;
$$ LANGUAGE plpgsql;
