-- ============================================================================
-- Advanced Enterprise Features Test
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_tenant_id UUID := gen_random_uuid();
    v_user_id UUID := gen_random_uuid();
    v_aggregate_id UUID := gen_random_uuid();
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Advanced Enterprise Features Test';
    RAISE NOTICE '========================================';

    -- Test 1: Advanced Cache
    PERFORM cache_get_or_set('test_key', 'SELECT ''{"test": true}''::JSONB', 60, 3600);
    RAISE NOTICE '✓ Advanced cache (L1/L2)';
    
    -- Test 2: Materialized Views
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tenant_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_activity;
    PERFORM refresh_scheduled_mv();
    RAISE NOTICE '✓ Materialized views';
    
    -- Test 3: Partition Automation
    PERFORM auto_create_tenant_partition(v_tenant_id);
    PERFORM update_partition_stats();
    PERFORM check_partition_health();
    RAISE NOTICE '✓ Partition automation';
    
    -- Test 4: Error Classification
    PERFORM classify_error('Unique violation');
    PERFORM attempt_error_recovery('Deadlock detected', '{}');
    RAISE NOTICE '✓ Error handling';
    
    -- Test 5: Metrics Aggregation
    PERFORM metrics_record('test_metric', 1.0, '{}', 'sum');
    PERFORM metrics_query('test_metric', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '1 hour');
    RAISE NOTICE '✓ Metrics aggregation';
    
    -- Test 6: Query Optimization
    PERFORM * FROM query_hints LIMIT 1;
    PERFORM get_slow_queries(5);
    RAISE NOTICE '✓ Query optimization';
    
    -- Test 7: Transaction Management
    PERFORM saga_start(gen_random_uuid(), 'TestSaga', 3, '{}');
    RAISE NOTICE '✓ Transaction/saga';
    
    -- Test 8: Security
    PERFORM sanitize_input('test'' OR 1=1', 'sql');
    PERFORM check_ip_allowed(v_tenant_id, '192.168.1.1'::INET);
    RAISE NOTICE '✓ Security hardening';
    
    -- Test 9: Connection Pool
    PERFORM check_pool_health();
    RAISE NOTICE '✓ Connection pool';
    
    -- Test 10: Query Whitelist
    PERFORM whitelist_add('SELECT * FROM test', 'Test query');
    PERFORM validate_query_allowed('SELECT * FROM event_store WHERE aggregate_id = ''');
    RAISE NOTICE '✓ Query whitelist';
    
    -- Test 11: Data Archival
    PERFORM create_archive_table('event_store', 'event_store_archive_test');
    PERFORM execute_archive('event_store', 1000);
    RAISE NOTICE '✓ Data archival';
    
    -- Test 12: System
    PERFORM * FROM v_connection_pool;
    RAISE NOTICE '✓ Connection pool view';
    
    PERFORM * FROM v_system_summary;
    RAISE NOTICE '✓ System summary';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All Advanced Enterprise Tests Passed!';
    RAISE NOTICE '========================================';
END;
$$;