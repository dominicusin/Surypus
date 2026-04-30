-- ============================================================================
-- Connection Pool Management
-- ============================================================================

-- Connection pool stats view
CREATE OR REPLACE VIEW v_connection_pool AS
SELECT 
    datname as database_name,
    COUNT(*) as total_connections,
    COUNT(CASE WHEN state = 'active' THEN 1 END) as active,
    COUNT(CASE WHEN state = 'idle' THEN 1 END) as idle,
    COUNT(CASE WHEN state = 'idle in transaction' THEN 1 END) as idle_in_transaction,
    COUNT(CASE WHEN state = 'active' AND query_start < NOW() - INTERVAL '5 seconds' THEN 1 END) as long_running,
    MAX(backend_start) as oldest_connection
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY datname;

-- Connection killer for admin
CREATE OR REPLACE FUNCTION admin_kill_idle_connections(
    p_min_age_seconds INT DEFAULT 300
) RETURNS INT AS $$
DECLARE
    v_killed INT := 0;
    v_pid BIGINT;
BEGIN
    FOR v_pid IN
        SELECT pid FROM pg_stat_activity
        WHERE state = 'idle'
          AND backend_start < NOW() - (p_min_age_seconds || ' seconds')::INTERVAL
          AND usename = current_user
    LOOP
        PERFORM pg_terminate_backend(v_pid);
        v_killed := v_killed + 1;
    END LOOP;
    
    RETURN v_killed;
END;
$$ LANGUAGE plpgsql;

-- Session configuration
CREATE OR REPLACE FUNCTION configure_session(
    p_tenant_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Set tenant context
    IF p_tenant_id IS NOT NULL THEN
        PERFORM set_config('surypus.tenant_id', p_tenant_id::TEXT, TRUE);
    END IF;
    
    -- Optimize for OLTP
    SET synchronous_commit = ON;
    SET statement_timeout = '30s';
    SET lock_timeout = '10s';
    SET idle_in_transaction_session_timeout = '60s';
END;
$$ LANGUAGE plpgsql;

-- Pool health check
CREATE OR REPLACE FUNCTION check_pool_health() RETURNS JSONB AS $$
DECLARE
    v_stats RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_stats FROM v_connection_pool LIMIT 1;
    
    v_result := jsonb_build_object(
        'total_connections', v_stats.total_connections,
        'active_connections', v_stats.active,
        'idle_connections', v_stats.idle,
        'long_running_queries', v_stats.long_running,
        'health_status', CASE 
            WHEN v_stats.long_running > 10 THEN 'critical'
            WHEN v_stats.active > v_stats.total_connections * 0.8 THEN 'degraded'
            ELSE 'healthy'
        END
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;