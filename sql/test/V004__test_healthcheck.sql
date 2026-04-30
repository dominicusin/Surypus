-- ============================================================================
-- Health Check Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_count INT;
BEGIN
    -- Check health_metrics table exists
    SELECT COUNT(*) INTO v_count FROM health_metrics;
    RAISE NOTICE '✓ Health metrics table exists: % entries', v_count;

    -- Check projection performance view
    SELECT COUNT(*) INTO v_count FROM v_projection_performance;
    RAISE NOTICE '✓ Projection performance view works: % projections tracked', v_count;

    -- Check slow projection alert function
    PERFORM projection_slow_alert(1000);
    RAISE NOTICE '✓ Slow projection alert function works';
END;
$$;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'Health Check Test Passed!';
RAISE NOTICE '========================================';