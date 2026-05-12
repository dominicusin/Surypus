-- Migration V225: Consolidated comprehensive summary and cost management
-- Original files: V225__comprehensive_summary.sql, V225__cost_management.sql

-- Cost Management Tables
CREATE TABLE IF NOT EXISTS cost_centers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    parent_id INT REFERENCES cost_centers(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cost_allocations (
    id SERIAL PRIMARY KEY,
    cost_center_id INT REFERENCES cost_centers(id),
    amount DECIMAL(15,2),
    account_id INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comprehensive Summary View (placeholder)
CREATE OR REPLACE VIEW v_migration_summary AS
SELECT 
    'migrations' as entity_type,
    COUNT(*) as count
FROM information_schema.tables
WHERE table_schema = 'public';
