-- V188: Integration configuration table
CREATE TABLE IF NOT EXISTS integration_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    adapter_type TEXT NOT NULL,
    credentials JSONB NOT NULL,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_integration_config_tenant ON integration_config(tenant_id);
CREATE INDEX IF NOT EXISTS idx_integration_config_type ON integration_config(adapter_type);
CREATE INDEX IF NOT EXISTS idx_integration_config_enabled ON integration_config(enabled);

-- Grant permissions (role may not exist on a fresh database; create it idempotently)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'surypus_app') THEN
    CREATE ROLE surypus_app;
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON integration_config TO surypus_app;
