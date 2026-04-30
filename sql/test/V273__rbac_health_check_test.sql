-- Test: verify RBAC health check function works
DO $$
BEGIN
  IF NOT (SELECT rbac_health_check()) THEN
    RAISE EXCEPTION 'RBAC health check reported unhealthy';
  END IF;
  RAISE NOTICE 'RBAC health check test passed';
END;
$$;
