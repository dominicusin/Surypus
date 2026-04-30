-- ============================================================================
-- Advanced Tenant Onboarding
-- ============================================================================

-- Tenant onboarding workflow
CREATE TABLE IF NOT EXISTS tenant_onboarding (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(tenant_id),
    status TEXT CHECK (status IN ('initiated', 'provisioning', 'configured', 'testing', 'active', 'suspended')) DEFAULT 'initiated',
    initiated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    current_step INT DEFAULT 0,
    steps JSONB DEFAULT '[
        {"step": 1, "name": "tenant_created", "status": "completed"},
        {"step": 2, "name": "schema_initialized", "status": "pending"},
        {"step": 3, "name": "rbac_configured", "status": "pending"},
        {"step": 4, "name": "resources_allocated", "status": "pending"},
        {"step": 5, "name": "health_verified", "status": "pending"}
    ]'::JSONB
);

-- Onboarding step processor
CREATE OR REPLACE FUNCTION process_onboarding_step(
    p_tenant_id UUID,
    p_step_name TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE tenant_onboarding SET
        current_step = current_step + 1,
        steps = jsonb_set(steps, 
            format('{%s,status}', current_step), 
            '"completed"'),
        status = CASE 
            WHEN p_step_name = 'resources_allocated' THEN 'testing'
            WHEN p_step_name = 'health_verified' THEN 'active'
            ELSE status
        END
    WHERE tenant_id = p_tenant_id;
    
    IF p_step_name = 'health_verified' THEN
        UPDATE tenant_onboarding SET completed_at = NOW() WHERE tenant_id = p_tenant_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Auto-partition for new tenant
CREATE OR REPLACE FUNCTION onboard_tenant(
    p_tenant_id UUID,
    p_tenant_name TEXT
) RETURNS VOID AS $$
BEGIN
    -- Create tenant
    INSERT INTO tenants (tenant_id, tenant_name, tenant_code, status)
    VALUES (p_tenant_id, p_tenant_name, LOWER(LEFT(p_tenant_name, 10)), 'active')
    ON CONFLICT (tenant_id) DO NOTHING;
    
    -- Create partition
    PERFORM auto_create_tenant_partition(p_tenant_id);
    
    -- Initialize onboarding
    INSERT INTO tenant_onboarding (tenant_id, status)
    VALUES (p_tenant_id, 'provisioning')
    ON CONFLICT (tenant_id) DO UPDATE SET status = 'provisioning';
    
    -- Initial RBAC
    PERFORM process_onboarding_step(p_tenant_id, 'tenant_created');
    PERFORM process_onboarding_step(p_tenant_id, 'schema_initialized');
END;
$$ LANGUAGE plpgsql;