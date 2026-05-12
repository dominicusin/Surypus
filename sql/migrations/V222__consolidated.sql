-- Migration V222: Consolidated quotas and validation
-- Original files: V222__advanced_quotas.sql, V222__final_ultimate_validation.sql

-- Advanced Quotas Configuration
CREATE TABLE IF NOT EXISTS api_quotas (
    id SERIAL PRIMARY KEY,
    client_id TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    max_requests INT DEFAULT 1000,
    window_seconds INT DEFAULT 3600,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_api_quotas_client ON api_quotas(client_id);

-- Final Validation Report (non-schema changing)
DO $$
DECLARE
    v_migrations_applied INT;
BEGIN
    SELECT COUNT(*) INTO v_migrations_applied 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name LIKE '%config';
    
    RAISE NOTICE 'Migration V222: Applied quotas + validation (tables: %)', v_migrations_applied;
END;
$$ LANGUAGE plpgsql;
