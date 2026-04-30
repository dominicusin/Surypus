-- Phase 6.1: Integration test for safe_invoke_function against an existing projection handler
DO $$
BEGIN
  -- Call an existing projection handler with dummy data
  PERFORM safe_invoke_function('proj_test_handler', '{}'::jsonb, '00000000-0000-0000-0000-000000000001'::uuid);
  RAISE NOTICE 'safe_invoke_function integration test completed';
END;
$$ LANGUAGE plpgsql;
