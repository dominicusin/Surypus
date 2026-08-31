-- ============================================================================
-- RBAC Schema - Role-Based Access Control
-- ============================================================================
-- Multi-tenant support with tenant isolation
-- OPA integration ready
-- ============================================================================

-- ============================================================================
-- TENANT MANAGEMENT
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    tenant_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_name         TEXT NOT NULL,
    tenant_code         VARCHAR(32) UNIQUE NOT NULL,
    status              VARCHAR(16) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    settings            JSONB DEFAULT '{}',
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tenant users association
CREATE TABLE IF NOT EXISTS tenant_users (
    tenant_id           UUID NOT NULL REFERENCES tenants(tenant_id),
    user_id             UUID NOT NULL,
    roles               TEXT[] DEFAULT '{}',
    is_owner            BOOLEAN DEFAULT FALSE,
    joined_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (tenant_id, user_id)
);

-- ============================================================================
-- USERS & AUTHENTICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    user_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email               TEXT UNIQUE NOT NULL,
    password_hash       TEXT,
    first_name          TEXT,
    last_name           TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    is_superuser        BOOLEAN DEFAULT FALSE,
    last_login          TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API keys for service-to-service communication
CREATE TABLE IF NOT EXISTS api_keys (
    key_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(tenant_id),
    user_id             UUID REFERENCES users(user_id),
    key_hash            TEXT NOT NULL,
    key_name            TEXT,
    scopes              TEXT[] DEFAULT '{}',
    expires_at          TIMESTAMP WITH TIME ZONE,
    last_used_at        TIMESTAMP WITH TIME ZONE,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ROLES & PERMISSIONS
-- ============================================================================

-- Role definitions
CREATE TABLE IF NOT EXISTS roles (
    role_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID REFERENCES tenants(tenant_id),  -- NULL = global role
    role_name           TEXT NOT NULL,
    role_code           VARCHAR(64) NOT NULL,
    description         TEXT,
    is_system           BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(tenant_id, role_code)
);

-- Permissions (resources + actions)
CREATE TABLE IF NOT EXISTS permissions (
    permission_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource            TEXT NOT NULL,  -- e.g., 'inventory', 'bills', 'reports'
    action              TEXT NOT NULL,  -- e.g., 'read', 'write', 'delete', 'approve'
    description         TEXT,
    conditions          JSONB DEFAULT '{}',  -- JSON schema for condition validation
    
    UNIQUE(resource, action)
);

-- Role-Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id             UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id       UUID NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    conditions          JSONB DEFAULT '{}',  -- Override conditions for this role
    
    PRIMARY KEY (role_id, permission_id)
);

-- User-Role mapping (can be tenant-specific)
CREATE TABLE IF NOT EXISTS user_roles (
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id             UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    tenant_id           UUID REFERENCES tenants(tenant_id),  -- NULL = global role
    granted_by          UUID REFERENCES users(user_id),
    expires_at          TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (user_id, role_id, tenant_id)
);

-- ============================================================================
-- POLICY DECISION LOG
-- ============================================================================

-- Audit log for authorization decisions
CREATE TABLE IF NOT EXISTS authz_decisions (
    decision_id         BIGSERIAL PRIMARY KEY,
    tenant_id           UUID,
    user_id             UUID,
    resource            TEXT NOT NULL,
    action              TEXT NOT NULL,
    resource_id         TEXT,
    decision            TEXT NOT NULL CHECK (decision IN ('allow', 'deny')),
    reason              TEXT,
    opa_input           JSONB,
    opa_result          JSONB,
    evaluated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_time_ms  INT
);

-- ============================================================================
-- INDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_tenant_users_user ON tenant_users(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant ON tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_tenant ON api_keys(tenant_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_authz_decisions_user ON authz_decisions(user_id, evaluated_at);
CREATE INDEX IF NOT EXISTS idx_authz_decisions_resource ON authz_decisions(resource, action);

-- ============================================================================
-- PERMISSION CHECK FUNCTIONS
-- ============================================================================

-- Check if user has specific permission
CREATE OR REPLACE FUNCTION has_permission(
    p_user_id UUID,
    p_resource TEXT,
    p_action TEXT,
    p_tenant_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN;
BEGIN
    -- Superusers have all permissions
    SELECT is_superuser INTO v_has_permission
    FROM users WHERE user_id = p_user_id;
    
    IF v_has_permission THEN
        RETURN TRUE;
    END IF;
    
    -- Check user roles for permission
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.permission_id
        WHERE ur.user_id = p_user_id
          AND p.resource = p_resource
          AND p.action = p_action
          AND (ur.tenant_id IS NULL OR ur.tenant_id = p_tenant_id)
          AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP)
    ) INTO v_has_permission;
    
    RETURN COALESCE(v_has_permission, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Check if user is tenant owner
CREATE OR REPLACE FUNCTION is_tenant_owner(
    p_user_id UUID,
    p_tenant_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_owner BOOLEAN;
BEGIN
    SELECT is_owner INTO v_is_owner
    FROM tenant_users
    WHERE tenant_id = p_tenant_id AND user_id = p_user_id;
    
    RETURN COALESCE(v_is_owner, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Get user permissions as JSON array
CREATE OR REPLACE FUNCTION get_user_permissions(
    p_user_id UUID,
    p_tenant_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_permissions JSONB;
BEGIN
    SELECT jsonb_agg(DISTINCT jsonb_build_object(
        'resource', p.resource,
        'action', p.action,
        'conditions', rp.conditions
    ))
    INTO v_permissions
    FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.permission_id
    WHERE ur.user_id = p_user_id
      AND (ur.tenant_id IS NULL OR ur.tenant_id = p_tenant_id)
      AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP);
    
    RETURN COALESCE(v_permissions, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- POLICY INPUT GENERATION
-- ============================================================================

-- Generate OPA input JSON
CREATE OR REPLACE FUNCTION generate_opa_input(
    p_user_id UUID,
    p_resource TEXT,
    p_action TEXT,
    p_tenant_id UUID DEFAULT NULL,
    p_resource_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_input JSONB;
    v_user JSONB;
    v_roles JSONB;
    v_permissions JSONB;
BEGIN
    -- Get user info
    SELECT jsonb_build_object(
        'user_id', user_id,
        'email', email,
        'is_active', is_active,
        'is_superuser', is_superuser
    )
    INTO v_user
    FROM users
    WHERE user_id = p_user_id;
    
    -- Get user roles
    SELECT jsonb_agg(jsonb_build_object(
        'role_id', role_id,
        'role_code', role_code,
        'is_system', is_system
    ))
    INTO v_roles
    FROM (
        SELECT r.role_id, r.role_code, r.is_system
        FROM user_roles ur
        JOIN roles r ON ur.role_id = r.role_id
        WHERE ur.user_id = p_user_id
          AND (ur.tenant_id IS NULL OR ur.tenant_id = p_tenant_id)
          AND (ur.expires_at IS NULL OR ur.expires_at > CURRENT_TIMESTAMP)
    ) roles;
    
    -- Get permissions
    v_permissions := get_user_permissions(p_user_id, p_tenant_id);
    
    -- Build input
    v_input := jsonb_build_object(
        'user', COALESCE(v_user, '{}'::JSONB),
        'roles', COALESCE(v_roles, '[]'::JSONB),
        'permissions', COALESCE(v_permissions, '[]'::JSONB),
        'tenant_id', p_tenant_id,
        'resource', p_resource,
        'action', p_action,
        'resource_id', p_resource_id,
        'timestamp', CURRENT_TIMESTAMP
    );
    
    RETURN v_input;
END;
$$ LANGUAGE plpgsql;

-- Log authorization decision
CREATE OR REPLACE FUNCTION log_authz_decision(
    p_tenant_id UUID,
    p_user_id UUID,
    p_resource TEXT,
    p_action TEXT,
    p_resource_id TEXT,
    p_decision TEXT,
    p_reason TEXT,
    p_opa_input JSONB,
    p_opa_result JSONB,
    p_processing_time_ms INT
)
RETURNS BIGINT AS $$
DECLARE
    v_decision_id BIGINT;
BEGIN
    INSERT INTO authz_decisions (
        tenant_id, user_id, resource, action, resource_id,
        decision, reason, opa_input, opa_result, processing_time_ms
    ) VALUES (
        p_tenant_id, p_user_id, p_resource, p_action, p_resource_id,
        p_decision, p_reason, p_opa_input, p_opa_result, p_processing_time_ms
    )
    RETURNING decision_id INTO v_decision_id;
    
    RETURN v_decision_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DEFAULT DATA
-- ============================================================================

-- System roles
INSERT INTO roles (role_name, role_code, is_system, description) VALUES
('Super Administrator', 'superadmin', TRUE, 'Full system access'),
('Tenant Administrator', 'tenant_admin', TRUE, 'Tenant-level administration'),
('Manager', 'manager', TRUE, 'Can manage resources within tenant'),
('User', 'user', TRUE, 'Standard user with read/write access'),
('Viewer', 'viewer', TRUE, 'Read-only access')
ON CONFLICT (tenant_id, role_code) DO NOTHING;

-- System permissions
INSERT INTO permissions (resource, action, description) VALUES
-- Inventory permissions
('inventory', 'read', 'View inventory and stock levels'),
('inventory', 'write', 'Modify inventory (receive/issue)'),
('inventory', 'delete', 'Delete inventory records'),
('inventory', 'adjust', 'Adjust stock quantities'),
('inventory', 'approve', 'Approve inventory adjustments'),

-- Bill permissions
('bill', 'read', 'View bills'),
('bill', 'write', 'Create and modify bills'),
('bill', 'delete', 'Delete bills'),
('bill', 'post', 'Post bills'),
('bill', 'cancel', 'Cancel posted bills'),
('bill', 'approve', 'Approve bills'),

-- Accounting permissions
('accounting', 'read', 'View accounting data'),
('accounting', 'write', 'Create accounting entries'),
('accounting', 'close', 'Close accounting periods'),
('accounting', 'report', 'Generate accounting reports'),

-- Person permissions
('person', 'read', 'View persons'),
('person', 'write', 'Create and modify persons'),
('person', 'delete', 'Delete persons'),

-- Salary permissions
('salary', 'read', 'View salary data'),
('salary', 'write', 'Create salary records'),
('salary', 'approve', 'Approve salary payments'),
('salary', 'pay', 'Process salary payments'),

-- Admin permissions
('admin', 'read', 'View admin settings'),
('admin', 'write', 'Modify admin settings'),
('admin', 'users', 'Manage users'),
('admin', 'roles', 'Manage roles'),
('admin', 'tenants', 'Manage tenants')
ON CONFLICT (resource, action) DO NOTHING;

-- Assign permissions to superadmin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r, permissions p
WHERE r.role_code = 'superadmin' AND r.tenant_id IS NULL
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign inventory permissions to manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r, permissions p
WHERE r.role_code = 'manager' AND r.tenant_id IS NULL
  AND p.resource IN ('inventory', 'bill', 'person')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Assign read permissions to viewer
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r, permissions p
WHERE r.role_code = 'viewer' AND r.tenant_id IS NULL
  AND p.action = 'read'
ON CONFLICT (role_id, permission_id) DO NOTHING;
