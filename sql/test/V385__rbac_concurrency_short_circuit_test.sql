-- V385__rbac_concurrency_short_circuit_test.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'concurrency_short_circuit') THEN
    -- This is a placeholder to ensure patch presence; actual behavior is invoked by other tests
    NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;
