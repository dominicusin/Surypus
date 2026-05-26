-- V1004: Integrations table for external system integration management
-- Matches the Surypus.API.Integrations.Integration Haskell data type

CREATE TABLE IF NOT EXISTS integrations (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    integration_type TEXT NOT NULL CHECK (integration_type IN ('BankOFX', 'BankISO20022', 'PaymentGateway', 'AccountingSync')),
    status TEXT NOT NULL DEFAULT 'StatusInactive' CHECK (status IN ('StatusActive', 'StatusInactive', 'StatusMaintenance')),
    endpoint TEXT,
    last_sync TIMESTAMP WITH TIME ZONE,
    last_error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_integrations_type ON integrations(integration_type);
CREATE INDEX IF NOT EXISTS idx_integrations_status ON integrations(status);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON integrations TO surypus_app;
GRANT USAGE, SELECT ON SEQUENCE integrations_id_seq TO surypus_app;
