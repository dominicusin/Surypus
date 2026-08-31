-- ============================================================================
-- SURYPUS INTEGRATION HEALTH MONITORING
-- Phase 20-3: Health monitoring for external integrations
-- ============================================================================

-- Integration health tracking table
CREATE TABLE IF NOT EXISTS integration_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    adapter_type TEXT NOT NULL,
    last_success TIMESTAMP WITH TIME ZONE,
    last_failure TIMESTAMP WITH TIME ZONE,
    failure_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'healthy',  -- 'healthy', 'degraded', 'failed'
    last_checked TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick health status queries
CREATE INDEX IF NOT EXISTS idx_integration_health_tenant_adapter ON integration_health(tenant_id, adapter_type);
CREATE INDEX IF NOT EXISTS idx_integration_health_status ON integration_health(status);
CREATE INDEX IF NOT EXISTS idx_integration_health_failure_count ON integration_health(failure_count);

-- Function to update health on successful integration
CREATE OR REPLACE FUNCTION record_integration_success(
    p_tenant_id UUID,
    p_adapter_type TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO integration_health (tenant_id, adapter_type, last_success, failure_count, status)
    VALUES (p_tenant_id, p_adapter_type, NOW(), 0, 'healthy')
    ON CONFLICT (tenant_id, adapter_type) 
    DO UPDATE SET
        last_success = NOW(),
        failure_count = 0,
        status = 'healthy',
        last_checked = NOW(),
        updated_at = NOW(),
        error_message = NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to update health on integration failure
CREATE OR REPLACE FUNCTION record_integration_failure(
    p_tenant_id UUID,
    p_adapter_type TEXT,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO integration_health (tenant_id, adapter_type, last_failure, failure_count, status, error_message)
    VALUES (p_tenant_id, p_adapter_type, NOW(), 1, 'degraded', p_error_message)
    ON CONFLICT (tenant_id, adapter_type) 
    DO UPDATE SET
        last_failure = NOW(),
        failure_count = integration_health.failure_count + 1,
        status = CASE 
            WHEN integration_health.failure_count + 1 >= 5 THEN 'failed'
            ELSE 'degraded'
        END,
        last_checked = NOW(),
        updated_at = NOW(),
        error_message = COALESCE(p_error_message, integration_health.error_message);
END;
$$ LANGUAGE plpgsql;

-- Function to get health status for an adapter
CREATE OR REPLACE FUNCTION get_integration_health(
    p_tenant_id UUID,
    p_adapter_type TEXT
) RETURNS TABLE (
    adapter_type TEXT,
    status TEXT,
    failure_count INTEGER,
    last_success TIMESTAMP WITH TIME ZONE,
    last_failure TIMESTAMP WITH TIME ZONE,
    error_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ih.adapter_type,
        ih.status,
        ih.failure_count,
        ih.last_success,
        ih.last_failure,
        ih.error_message
    FROM integration_health ih
    WHERE ih.tenant_id = p_tenant_id 
      AND ih.adapter_type = p_adapter_type;
END;
$$ LANGUAGE plpgsql;

-- Function to get all unhealthy integrations for alerting
CREATE OR REPLACE FUNCTION get_unhealthy_integrations(
    p_min_failure_count INTEGER DEFAULT 3
) RETURNS TABLE (
    tenant_id UUID,
    adapter_type TEXT,
    failure_count INTEGER,
    status TEXT,
    last_failure TIMESTAMP WITH TIME ZONE,
    error_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ih.tenant_id,
        ih.adapter_type,
        ih.failure_count,
        ih.status,
        ih.last_failure,
        ih.error_message
    FROM integration_health ih
    WHERE ih.failure_count >= p_min_failure_count
      AND ih.status IN ('degraded', 'failed')
    ORDER BY ih.failure_count DESC, ih.last_failure DESC;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_integration_health_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS integration_health_updated_at_trigger ON integration_health;
CREATE TRIGGER integration_health_updated_at_trigger
    BEFORE UPDATE ON integration_health
    FOR EACH ROW
    EXECUTE FUNCTION update_integration_health_updated_at();
