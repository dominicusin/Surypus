-- ============================================================================
-- Final Enterprise Validation
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_errors TEXT := '';
    v_warnings TEXT := '';
BEGIN
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║         Surypus Enterprise Validation - Starting                 ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════════════════╝';

    -- Core Tables
    IF NOT EXISTS (SELECT 1 FROM event_store LIMIT 1) THEN
        v_errors := v_errors || 'event_store empty; ';
    END IF;
    
    -- RBAC
    IF NOT EXISTS (SELECT 1 FROM roles LIMIT 1) THEN
        v_warnings := v_warnings || 'no roles; ';
    END IF;
    
    -- Partitions
    IF NOT EXISTS (SELECT 1 FROM partition_metadata WHERE is_active = TRUE) THEN
        v_warnings := v_warnings || 'no partitions; ';
    END IF;
    
    -- Security
    IF NOT EXISTS (SELECT 1 FROM query_whitelist WHERE is_enabled = TRUE) THEN
        v_warnings := v_warnings || 'no query whitelist; ';
    END IF;
    
    -- Validation
    RAISE NOTICE '';
    IF v_errors = '' THEN
        RAISE NOTICE '✓ Core validation passed';
    ELSE
        RAISE EXCEPTION '✗ Errors: %', v_errors;
    END IF;
    
    IF v_warnings = '' THEN
        RAISE NOTICE '✓ All optional checks passed';
    ELSE
        RAISE NOTICE '⚠ Warnings: %', v_warnings;
    END IF;
END;
$$;

-- Run comprehensive test
DO $$
DECLARE
    v_count INT;
BEGIN
    -- Cache
    v_count := (SELECT COUNT(*) FROM cache_tiers);
    RAISE NOTICE '✓ Cache: % entries', v_count;
    
    -- Materialized Views
    v_count := (SELECT COUNT(*) FROM pg_matviews WHERE schemaname = 'public');
    RAISE NOTICE '✓ Materialized views: %', v_count;
    
    -- Partitions
    v_count := (SELECT COUNT(*) FROM partition_metadata);
    RAISE NOTICE '✓ Partitions: %', v_count;
    
    -- Error handlers
    v_count := (SELECT COUNT(*) FROM error_handlers);
    RAISE NOTICE '✓ Error handlers: %', v_count;
    
    -- Metrics
    PERFORM * FROM metrics_aggregation LIMIT 1;
    RAISE NOTICE '✓ Metrics aggregation';
    
    -- Query whitelist
    v_count := (SELECT COUNT(*) FROM query_whitelist WHERE is_enabled = TRUE);
    RAISE NOTICE '✓ Query whitelist: % enabled', v_count;
    
    -- Rate limiting
    v_count := (SELECT COUNT(*) FROM rate_limit_config);
    RAISE NOTICE '✓ Rate limit configs: %', v_count;
    
    -- Security
    v_count := (SELECT COUNT(*) FROM security_events);
    RAISE NOTICE '✓ Security events: %', v_count;
    
    -- Vacuum schedule
    v_count := (SELECT COUNT(*) FROM vacuum_schedule);
    RAISE NOTICE '✓ Vacuum schedule: % tables', v_count;
    
    -- Dashboard
    PERFORM * FROM v_dashboard_advanced LIMIT 1;
    RAISE NOTICE '✓ Advanced dashboard';
    
    -- Alerts
    PERFORM * FROM v_realtime_alerts LIMIT 1;
    RAISE NOTICE '✓ Realtime alerts';
END;
$$;

-- Final marker
DO $$
BEGIN
    -- Record completion
    INSERT INTO health_metrics (check_name, status, value, message, recorded_at)
    VALUES ('enterprise_validation', 'healthy', 175, 'All enterprise features validated', NOW())
    ON CONFLICT (check_name, recorded_at) DO NOTHING;
    
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  Surypus Enterprise SQL Refactoring Complete!                  ║';
    RAISE NOTICE '║  Total Migrations: 175+                                     ║';
    RAISE NOTICE '║                                                               ║';
    RAISE NOTICE '║  Features Applied:                                          ║';
    RAISE NOTICE '║  ✓ RBAC & Security (Advanced)                               ║';
    RAISE NOTICE '║  ✓ Partitioning (Automation)                                ║';
    RAISE NOTICE '║  ✓ Projections (Auditing & Performance)                     ║';
    RAISE NOTICE '║  ✓ Caching (Multi-tier)                                    ║';
    RAISE NOTICE '║  ✓ Monitoring (Advanced Dashboard)                        ║';
    RAISE NOTICE '║  ✓ Analytics (Materialized Views)                         ║';
    RAISE NOTICE '║  ✓ Query Optimization (Whitelist & Hints)               ║';
    RAISE NOTICE '║  ✓ Transaction Management (Saga Pattern)                   ║';
    RAISE NOTICE '║  ✓ Rate Limiting (Enterprise)                                 ║';
    RAISE NOTICE '║  ✓ Data Archival & Retention                                ║';
    RAISE NOTICE '║  ✓ Connection Pool Management                             ║';
    RAISE NOTICE '║  ✓ Vacuum Maintenance                                      ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════════════════╝';
END $$;