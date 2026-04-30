-- ============================================================================
-- Advanced Multi-Cloud Orchestration
-- ============================================================================

-- Cloud resource registry
CREATE TABLE IF NOT EXISTS cloud_resources (
    id SERIAL PRIMARY KEY,
    resource_id TEXT NOT NULL,
    cloud_provider TEXT CHECK (cloud_provider IN ('aws', 'azure', 'gcp', 'on_prem')),
    resource_type TEXT NOT NULL,
    region TEXT,
    status TEXT CHECK (status IN ('active', 'inactive', 'provisioning', 'terminating')),
    config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cross-cloud replication
CREATE TABLE IF NOT EXISTS cross_cloud_replication (
    id SERIAL PRIMARY KEY,
    source_resource_id INT REFERENCES cloud_resources(id),
    target_resource_id INT REFERENCES cloud_resources(id),
    replication_type TEXT CHECK (replication_type IN ('sync', 'async', 'eventual')),
    lag_threshold_ms INT DEFAULT 1000,
    status TEXT CHECK (status IN ('active', 'paused', 'error'))
);

-- Provision cloud resource
CREATE OR REPLACE FUNCTION provision_cloud_resource(
    p_cloud_provider TEXT,
    p_resource_type TEXT,
    p_region TEXT,
    p_config JSONB
) RETURNS INT AS $$
DECLARE
    v_resource_id INT;
    v_resource_id_text TEXT;
BEGIN
    v_resource_id_text := p_cloud_provider || '_' || p_resource_type || '_' || EXTRACT(EPOCH FROM NOW())::TEXT;
    
    INSERT INTO cloud_resources (resource_id, cloud_provider, resource_type, region, status, config)
    VALUES (v_resource_id_text, p_cloud_provider, p_resource_type, p_region, 'provisioning', p_config)
    RETURNING id INTO v_resource_id;
    
    RETURN v_resource_id;
END;
$$ LANGUAGE plpgsql;

-- Check cross-region latency
CREATE OR REPLACE FUNCTION check_cross_region_latency(
    p_source_region TEXT,
    p_target_region TEXT
) RETURNS INT AS $$
BEGIN
    RETURN 50;  -- Simulated
END;
$$ LANGUAGE plpgsql;