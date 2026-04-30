-- V349__rbac_concurrency_alerts_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_concurrency_alert') THEN
    PERFORM rbac.canon_concurrency_alert('test alert');
  END IF;
END;
$$ LANGUAGE plpgsql;
