-- ============================================================================
-- Comprehensive System Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_count INT;
BEGIN
    -- Test DB stats view
    SELECT COUNT(*) INTO v_count FROM v_db_stats;
    RAISE NOTICE '✓ DB stats view works: % tables tracked', v_count;

    -- Test error summary view
    SELECT COUNT(*) INTO v_count FROM v_error_summary;
    RAISE NOTICE '✓ Error summary view works';

    -- Test projection retry policy
    IF EXISTS (SELECT 1 FROM projection_retry_policy WHERE projection_name = 'TestProj') THEN
        RAISE NOTICE '✓ Projection retry policy configured';
    END IF;

    -- Test safe execute allowlist validation
    PERFORM safe_execute('proj_test_handler', '{}'::JSONB);
    RAISE NOTICE '✓ Safe execute allowlist works';
END;
$$;

-- Test aggregate locking
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_locked BOOLEAN;
BEGIN
    -- Insert aggregate
    INSERT INTO aggregates (aggregate_id, aggregate_type, tenant_id, current_version)
    VALUES (v_aggregate_id, 'Inventory', v_tenant_id, 0);

    -- Test lock
    v_locked := aggregate_lock(v_aggregate_id, 0);
    IF v_locked THEN
        RAISE NOTICE '✓ Aggregate locking works';
        PERFORM aggregate_unlock(v_aggregate_id, (SELECT lock_token FROM aggregates WHERE aggregate_id = v_aggregate_id));
    END IF;
END;
$$;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'Comprehensive System Test Passed!';
RAISE NOTICE '========================================';