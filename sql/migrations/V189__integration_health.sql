-- V189: Integration health monitoring table
CREATE TABLE IF NOT EXISTS integration_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    adapter_type TEXT NOT NULL,
    last_success TIMESTAMPTZ,
    last_failure TIMESTAMPTZ,
    failure_count INT DEFAULT 0,
    status TEXT DEFAULT 'healthy' CHECK (status IN ('healthy', 'degraded', 'down')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_integration_health_tenant ON integration_health(tenant_id);
CREATE INDEX IF NOT EXISTS idx_integration_health_type ON integration_health(adapter_type);
CREATE INDEX IF NOT EXISTS idx_integration_health_status ON integration_health(status);
CREATE INDEX IF NOT EXISTS idx_integration_health_failure_count ON integration_health(failure_count);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON integration_health TO surypus_app;
