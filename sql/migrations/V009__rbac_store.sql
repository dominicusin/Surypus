-- V009__rbac_store.sql
-- RBAC dynamic roles and delegation grants

-- Dynamic roles table
CREATE TABLE IF NOT EXISTS rbac_dynamic_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Scoped permissions for dynamic roles
CREATE TABLE IF NOT EXISTS rbac_scoped_permissions (
    id SERIAL PRIMARY KEY,
    role_id INT NOT NULL REFERENCES rbac_dynamic_roles(id) ON DELETE CASCADE,
    permission VARCHAR(100) NOT NULL,
    resource VARCHAR(255),
    scope_type VARCHAR(50) DEFAULT 'global',  -- 'global', 'resource', 'tenant'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Delegation grants for principal-to-principal permissions
CREATE TABLE IF NOT EXISTS rbac_delegation_grants (
    id SERIAL PRIMARY KEY,
    from_principal VARCHAR(255) NOT NULL,
    to_principal VARCHAR(255) NOT NULL,
    permission VARCHAR(100) NOT NULL,
    resource VARCHAR(255),
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_rbac_delegation_to_principal ON rbac_delegation_grants(to_principal);
CREATE INDEX IF NOT EXISTS idx_rbac_delegation_expires_at ON rbac_delegation_grants(expires_at);
CREATE INDEX IF NOT EXISTS idx_rbac_scoped_permissions_role_id ON rbac_scoped_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_rbac_delegation_permission ON rbac_delegation_grants(permission);

-- Function to cleanup expired RBAC grants
CREATE OR REPLACE FUNCTION cleanup_expired_rbac_grants()
RETURNS INT AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM rbac_delegation_grants
    WHERE expires_at IS NOT NULL AND expires_at < NOW();
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- Insert default admin role
INSERT INTO rbac_dynamic_roles (name) VALUES ('admin')
ON CONFLICT (name) DO NOTHING;

-- Grant admin all permissions
INSERT INTO rbac_scoped_permissions (role_id, permission, resource, scope_type)
SELECT id, '*', NULL, 'global'
FROM rbac_dynamic_roles
WHERE name = 'admin'
ON CONFLICT DO NOTHING;
