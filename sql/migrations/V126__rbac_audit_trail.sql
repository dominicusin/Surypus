-- RBAC audit trail: log access decisions for compliance
CREATE TABLE IF NOT EXISTS rbac_audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    tenant_id UUID,
    permission_code TEXT,
    decision TEXT CHECK (decision IN ('allow', 'deny')),
    reason TEXT,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rbac_audit_user ON rbac_audit_log(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_rbac_audit_tenant ON rbac_audit_log(tenant_id, created_at);