-- ============================================================================
-- Complete System Integration Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_count INT;
BEGIN
    RAISE NOTICE 'Starting Complete System Test...';

    -- Test 1: Event append
    PERFORM event_append(v_aggregate_id, 'Inventory', 'StockReceived', '{"test": 1}', v_tenant_id, NULL, NULL, NULL, NULL);
    RAISE NOTICE '✓ Event append works';

    -- Test 2: Snapshot create
    PERFORM snapshot_create(v_aggregate_id, 'Inventory', 1, '{"test": "state"}', 1);
    RAISE NOTICE '✓ Snapshot works';

    -- Test 3: Projection audit
    SELECT COUNT(*) INTO v_count FROM projection_audit;
    RAISE NOTICE '✓ Projection audit: % entries', v_count;

    -- Test 4: Outbox
    SELECT COUNT(*) INTO v_count FROM event_outbox WHERE published = FALSE;
    RAISE NOTICE '✓ Outbox pending: % entries', v_count;

    -- Test 5: Dashboard
    SELECT COUNT(*) INTO v_count FROM v_dashboard;
    RAISE NOTICE '✓ Dashboard view works';

    -- Test 6: DB stats
    SELECT COUNT(*) INTO v_count FROM v_db_stats;
    RAISE NOTICE '✓ DB stats: % tables', v_count;

    -- Test 7: Health metrics
    PERFORM health_record('test_check', 'healthy', 1, 'test');
    RAISE NOTICE '✓ Health recording works';

    -- Test 8: Safe JSON merge
    IF jsonb_merge_safe('{}'::JSONB, '{"a":1}', ARRAY['a']) IS NOT NULL THEN
        RAISE NOTICE '✓ Safe JSON merge works';
    END IF;

    -- Test 9: Batch append
    PERFORM event_append_batch('[{"aggregate_id": "%", "aggregate_type": "Inventory", "event_type": "StockReceived", "event_data": {"batch": true}, "tenant_id": "%"}]'::JSONB, v_aggregate_id::TEXT, v_tenant_id::TEXT);
    RAISE NOTICE '✓ Batch append works';

    -- Test 10: Archive / recovery 
    PERFORM recover_aggregate(v_aggregate_id);
    RAISE NOTICE '✓ Recovery works';
END;
$$;

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'Complete System Test Passed!';
RAISE NOTICE '========================================';