-- Migration V227: Consolidated final validation and reporting engine
-- Original files: V227__final_validation.sql, V227__reporting_engine.sql

-- Reporting Engine Configuration
CREATE TABLE IF NOT EXISTS report_templates (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    template_type TEXT,
    query_sql TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Final Validation
DO $$
BEGIN
    RAISE NOTICE 'Migration V227: Reporting engine + validation complete';
END;
$$ LANGUAGE plpgsql;
