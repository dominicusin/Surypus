-- ============================================================================
-- Final Comprehensive Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_count INT;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Starting Final Comprehensive Test';
    RAISE NOTICE '========================================';

    -- Core functionality
    PERFORM event_append(v_aggregate_id, 'Inventory', 'StockReceived', '{"final": true}', v_tenant_id, NULL, NULL, NULL, NULL);
    RAISE NOTICE '✓ Event append';
    
    PERFORM snapshot_create(v_aggregate_id, 'Inventory', 1, '{}', 1);
    RAISE NOTICE '✓ Snapshot';
    
    -- System summary
    SELECT * INTO v_count FROM v_system_summary;
    RAISE NOTICE '✓ System summary: % columns', v_count;

    -- Advanced features
    PERFORM cache_set('final_test', '{"ok": true}', 60);
    PERFORM cache_get('final_test');
    RAISE NOTICE '✓ Cache';
    
    PERFORM check_rate_limit('final_user', 'test', 100);
    RAISE NOTICE '✓ Rate limiting';
    
    PERFORM list_partitions('event_store');
    RAISE NOTICE '✓ Partitions';
    
    PERFORM scan_pii_columns();
    RAISE NOTICE '✓ PII detection';
    
    -- Analytics
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_aggregate_counts;
    RAISE NOTICE '✓ Materialized views';
    
    -- Scheduled jobs
    PERFORM run_scheduled_jobs();
    RAISE NOTICE '✓ Scheduled jobs';
    
    -- Notifications
    PERFORM notify_user(v_tenant_id, NULL, 'Test notification', 'Final test complete');
    RAISE NOTICE '✓ Notifications';
    
    -- Scheduled jobs check
    IF EXISTS (SELECT 1 FROM scheduled_jobs WHERE is_active) THEN
        RAISE NOTICE '✓ Scheduled jobs registered';
    END IF;

    -- Webhooks
    INSERT INTO webhooks (tenant_id, url, event_types, is_active)
    VALUES (v_tenant_id, 'https://example.com/webhook', ARRAY['StockReceived'], TRUE)
    ON CONFLICT DO NOTHING;
    RAISE NOTICE '✓ Webhooks';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All Final Tests Passed!';
    RAISE NOTICE 'Surypus SQL Refactoring Complete';
    RAISE NOTICE '========================================';
END;
$$;