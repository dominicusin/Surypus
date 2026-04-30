-- ============================================================================
-- Comprehensive Audit Trail
-- ============================================================================

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_trail (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID DEFAULT gen_random_uuid(),
    user_id UUID,
    tenant_id UUID,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    changes JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_trail(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_trail(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_tenant ON audit_trail(tenant_id, created_at);

-- Audit trigger helper
CREATE OR REPLACE FUNCTION audit_trigger_func() RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_tenant_id UUID;
BEGIN
    BEGIN
        v_user_id := current_setting('surypus.user_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    BEGIN
        v_tenant_id := current_setting('surypus.tenant_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_tenant_id := NULL;
    END;
    
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_trail (action, entity_type, new_values, user_id, tenant_id)
        VALUES (TG_OP, TG_TABLE_NAME, to_jsonb(NEW), v_user_id, v_tenant_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_trail (action, entity_type, old_values, new_values, user_id, tenant_id)
        VALUES (TG_OP, TG_TABLE_NAME, to_jsonb(OLD), to_jsonb(NEW), v_user_id, v_tenant_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_trail (action, entity_type, old_values, user_id, tenant_id)
        VALUES (TG_OP, TG_TABLE_NAME, to_jsonb(OLD), v_user_id, v_tenant_id);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Get audit history
CREATE OR REPLACE FUNCTION get_audit_history(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_limit INT DEFAULT 100
) RETURNS TABLE(
    action TEXT,
    old_values JSONB,
    new_values JSONB,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT at.action, at.old_values, at.new_values, at.user_id, at.created_at
    FROM audit_trail at
    WHERE at.entity_type = p_entity_type AND at.entity_id = p_entity_id
    ORDER BY at.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;