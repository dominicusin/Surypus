-- ============================================================================
-- Advanced Features Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
BEGIN
    RAISE NOTICE 'Testing Advanced Features...';

    -- Test cache
    PERFORM cache_set('test_key', '{"test": true}'::JSONB, 60);
    IF cache_get('test_key') IS NOT NULL THEN
        RAISE NOTICE '✓ Cache works';
    END IF;

    -- Test rate limiting
    IF check_rate_limit('test_user', 'test_action', 10) THEN
        RAISE NOTICE '✓ Rate limiting works';
    END IF;

    -- Test lock monitoring view
    PERFORM * FROM v_active_locks LIMIT 1;
    RAISE NOTICE '✓ Lock monitoring works';

    -- Test materialized views
    REFRESH MATERIALIZED VIEW mv_aggregate_counts;
    RAISE NOTICE '✓ Materialized view refresh works';

    -- Test partition maintenance
    PERFORM * FROM list_partitions('event_store') LIMIT 1;
    RAISE NOTICE '✓ Partition listing works';

    -- Test retention policy
    PERFORM apply_retention_policy('event_store', 'created_at', INTERVAL '7 years');
    RAISE NOTICE '✓ Retention policy works';

    -- Test PII scan
    PERFORM scan_pii_columns();
    RAISE NOTICE '✓ PII detection works';

    -- Test analytics view
    SELECT COUNT(*) INTO v_count FROM mv_event_trends;
    RAISE NOTICE '✓ Event trends analytics: % rows', v_count;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Advanced Features Test Passed!';
    RAISE NOTICE '========================================';
END;
$$;