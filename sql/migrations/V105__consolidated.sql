-- Migration V105: Consolidated event store aggregation and RBAC finalize
-- Original files: V105__idx_event_store_agg_ver.sql, V105__rbac_finalize.sql

-- Event store aggregation index
CREATE INDEX IF NOT EXISTS idx_event_store_agg_ver ON event_store (
    aggregate_id,
    aggregate_type,
    event_version
);

-- RBAC Finalize: Add remaining permissions and roles for complete coverage
DO $$ BEGIN
    -- Ensure core permissions exist
    INSERT INTO permissions (name, code, description) VALUES
        ('accounting_view', 'accounting_view', 'View accounting records'),
        ('accounting_edit', 'accounting_edit', 'Edit accounting records')
    ON CONFLICT (name) DO NOTHING;
    
    -- Grant to admin role if exists
    IF EXISTS (SELECT 1 FROM roles WHERE name = 'admin') THEN
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.id, p.id
        FROM roles r
        CROSS JOIN permissions p
        WHERE r.name = 'admin' AND p.code IN ('accounting_view', 'accounting_edit')
        ON CONFLICT DO NOTHING;
    END IF;
END $$ LANGUAGE plpgsql;
