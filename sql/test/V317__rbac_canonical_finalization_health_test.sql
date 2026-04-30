-- V317__rbac_canonical_finalization_health_test.sql
-- Basic health check invocation
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'canon_health') THEN
    RAISE NOTICE 'RBAC Canon health: %', rbac.canon_health();
  END IF;
END;
$$ LANGUAGE plpgsql;
