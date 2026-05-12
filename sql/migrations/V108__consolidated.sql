-- Migration V108: Consolidated projection FIFO aggregation and RBAC seed unify
-- Original files: V108__projection_fifo_agg_index.sql, V108__rbac_seed_unify.sql

-- Projection FIFO Aggregation Index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projection_fifo_agg ON projection_fifo (
    tenant_id,
    created_at DESC
);

-- RBAC Seed Unify v2 (different approach from v1)
DO $$ BEGIN
    -- Ensure permissions exist
    INSERT INTO permissions (code, description)
    SELECT pm.permission_code, pm.description
    FROM (VALUES 
        ('read_basic', 'Read basic data'),
        ('write_basic', 'Write basic data'),
        ('admin_all', 'Full admin access')
    ) AS pm(permission_code, description)
    WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = pm.permission_code);
END $$ LANGUAGE plpgsql;
