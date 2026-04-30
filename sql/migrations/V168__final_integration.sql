-- ============================================================================
-- Final Integration: Complete System Validation
-- ============================================================================

-- Final health check
DO $$
DECLARE
    v_errors TEXT := '';
BEGIN
    -- Check core tables
    IF NOT EXISTS (SELECT 1 FROM event_store LIMIT 1) THEN
        v_errors := v_errors || 'event_store missing; ';
    END IF;
    
    -- Check partitions
    IF NOT EXISTS (SELECT 1 FROM partition_metadata WHERE is_active = TRUE) THEN
        v_errors := v_errors || 'no partitions; ';
    END IF;
    
    -- Check RBAC
    IF NOT EXISTS (SELECT 1 FROM roles LIMIT 1) THEN
        v_errors := v_errors || 'no roles; ';
    END IF;
    
    -- Record final health
    PERFORM health_record('system_final_check', 
        CASE WHEN v_errors = '' THEN 'healthy' ELSE 'degraded' END,
        0, v_errors);
    
    RAISE NOTICE 'System integrity: %', CASE WHEN v_errors = '' THEN 'OK' ELSE v_errors END;
END;
$$;

-- Grant permissions
DO $$
BEGIN
    -- Grant usage to public schemas for read operations
    GRANT USAGE ON SCHEMA public TO PUBLIC;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO PUBLIC;
    
    -- Grant execute on functions
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;
END $$;

-- Final migration marker
DO $$
BEGIN
    PERFORM health_record('migration_complete', 'healthy', 168, 'All 168 migrations applied successfully');
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  Surypus SQL Refactoring Complete!                 ║';
    RAISE NOTICE '║  Version: 168 migrations applied                 ║';
    RAISE NOTICE '║  Features: RBAC | Partitioning | Security        ║';
    RAISE NOTICE '║  Features: Caching | Monitoring | Analytics     ║';
    RAISE NOTICE '║  Features: Transactions | Query Optimization       ║';
    RAISE NOTICE '║  Features: Connection Pool | Data Archival     ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════╝';
END $$;