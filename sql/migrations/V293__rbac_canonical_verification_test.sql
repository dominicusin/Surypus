-- Test: verify RBAC canonical API through verify_rbac_api_consistency
DO $$
BEGIN
  IF NOT (SELECT verify_rbac_api_consistency()) THEN
    RAISE EXCEPTION 'RBAC canonical API test failed';
  END IF;
  RAISE NOTICE 'RBAC canonical API test passed';
END;
$$;
