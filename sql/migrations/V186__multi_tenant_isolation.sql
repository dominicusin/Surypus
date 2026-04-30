-- ============================================================================
-- Multi-Tenant Isolation Levels
-- ============================================================================

-- Tenant isolation levels
CREATE TABLE IF NOT EXISTS tenant_isolation_levels (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id),
    isolation_level TEXT CHECK (isolation_level IN ('shared', 'schema', 'database')) DEFAULT 'shared',
    dedicated_resources BOOLEAN DEFAULT FALSE,
    max_connections INT DEFAULT 100,
    storage_quota_gb INT DEFAULT 100,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Per-tenant connection pool
CREATE OR REPLACE FUNCTION get_tenant_connection_limit(
    p_tenant_id UUID
) RETURNS INT AS $$
DECLARE
    v_limit INT;
BEGIN
    SELECT max_connections INTO v_limit
    FROM tenant_isolation_levels
    WHERE tenant_id = p_tenant_id;
    
    RETURN COALESCE(v_limit, 100);
END;
$$ LANGUAGE plpgsql;

-- Tenant resource usage
CREATE TABLE IF NOT EXISTS tenant_resource_usage (
    tenant_id UUID REFERENCES tenants(tenant_id),
    period_start TIMESTAMP WITH TIME ZONE,
    period_end TIMESTAMP WITH TIME ZONE,
    connections_used INT DEFAULT 0,
    storage_bytes BIGINT DEFAULT 0,
    api_calls INT DEFAULT 0,
    PRIMARY KEY(tenant_id, period_start)
);

-- Track resource usage
CREATE OR REPLACE FUNCTION track_resource_usage(
    p_tenant_id UUID,
    p_resource_type TEXT,
    p_value INT
) RETURNS VOID AS $$
DECLARE
    v_period TIMESTAMP := DATE_TRUNC('hour', NOW());
BEGIN
    INSERT INTO tenant_resource_usage (tenant_id, period_start, connections_used, storage_bytes, api_calls)
    VALUES (p_tenant_id, v_period, 0, 0, 0)
    ON CONFLICT (tenant_id, period_start) DO UPDATE
    SET connections_used = tenant_resource_usage.connections_used + 
        CASE p_resource_type WHEN 'connections' THEN p_value ELSE 0 END,
        api_calls = tenant_resource_usage.api_calls + 
        CASE p_resource_type WHEN 'api_calls' THEN p_value ELSE 0 END;
END;
$$ LANGUAGE plpgsql;