-- ============================================================================
-- Multi-Region Support
-- ============================================================================

-- Region configuration
CREATE TABLE IF NOT EXISTS regions (
    region_id SERIAL PRIMARY KEY,
    region_code TEXT UNIQUE NOT NULL,
    region_name TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    latency_ms INT
);

-- Geo-routing rules
CREATE TABLE IF NOT EXISTS geo_routing_rules (
    id SERIAL PRIMARY KEY,
    source_region TEXT NOT NULL,
    target_region TEXT NOT NULL,
    routing_type TEXT CHECK (routing_type IN ('latency', 'cost', 'compliance')),
    priority INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE
);

-- Data residency rules
CREATE TABLE IF NOT EXISTS data_residency_rules (
    id SERIAL PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(tenant_id),
    data_type TEXT NOT NULL,
    required_region TEXT NOT NULL,
    is_compliance BOOLEAN DEFAULT FALSE
);

-- Regional replication status
CREATE TABLE IF NOT EXISTS regional_replication (
    id SERIAL PRIMARY KEY,
    source_region TEXT NOT NULL,
    target_region TEXT NOT NULL,
    replication_lag_ms INT DEFAULT 0,
    last_sync TIMESTAMPTZ,
    status TEXT CHECK (status IN ('syncing', 'synced', 'lagged', 'error'))
);

-- Get best region for tenant
CREATE OR REPLACE FUNCTION get_best_region(
    p_tenant_id UUID
) RETURNS TEXT AS $$
DECLARE
    v_rules RECORD;
    v_region TEXT;
BEGIN
    -- Check compliance requirements first
    SELECT required_region INTO v_region
    FROM data_residency_rules
    WHERE tenant_id = p_tenant_id AND is_compliance = TRUE
    LIMIT 1;
    
    IF v_region IS NOT NULL THEN
        RETURN v_region;
    END IF;
    
    -- Otherwise use latency-based routing
    SELECT r.region_code INTO v_region
    FROM regions r
    WHERE r.is_active = TRUE
    ORDER BY r.latency_ms ASC
    LIMIT 1;
    
    RETURN v_region;
END;
$$ LANGUAGE plpgsql;