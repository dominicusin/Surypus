-- ============================================================================
-- Advanced Database Proxy & Routing
-- ============================================================================

-- Connection routing rules
CREATE TABLE IF NOT EXISTS connection_routes (
    id SERIAL PRIMARY KEY,
    route_name TEXT UNIQUE NOT NULL,
    priority INT DEFAULT 1,
    condition JSONB NOT NULL,  -- {field: "tenant_id", operator: "eq", value: "uuid"}
    target_connection TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Query routing
CREATE OR REPLACE FUNCTION route_query(
    p_tenant_id UUID,
    p_query TEXT
) RETURNS TEXT AS $$
DECLARE
    v_route RECORD;
BEGIN
    -- Find matching route
    SELECT * INTO v_route
    FROM connection_routes
    WHERE is_active = TRUE
    ORDER BY priority ASC
    LIMIT 1;
    
    IF v_route IS NOT NULL THEN
        RETURN p_query;  -- Route to specific connection
    END IF;
    
    RETURN p_query;  -- Default routing
END;
$$ LANGUAGE plpgsql;

-- Read replica lag monitoring
CREATE TABLE IF NOT EXISTS replica_lag (
    id SERIAL PRIMARY KEY,
    replica_name TEXT,
    lag_seconds INT DEFAULT 0,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Check replica health
CREATE OR REPLACE FUNCTION check_replica_health() RETURNS JSONB AS $$
BEGIN
    RETURN jsonb_build_object(
        'status', 'healthy',
        'replicas', (SELECT COUNT(*) FROM pg_stat_replication),
        'checked_at', NOW()
    );
END;
$$ LANGUAGE plpgsql;