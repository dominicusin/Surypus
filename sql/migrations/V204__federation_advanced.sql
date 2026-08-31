-- ============================================================================
-- Federation & Cross-Tenant Advanced Features  
-- ============================================================================

-- Tenant federation configuration
CREATE TABLE IF NOT EXISTS tenant_federation (
    federation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    federation_name TEXT NOT NULL,
    member_tenants UUID[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cross-tenant query execution
CREATE OR REPLACE FUNCTION federated_query(
    p_federation_id UUID,
    p_sql TEXT
) RETURNS TABLE(result JSONB) AS $$
DECLARE
    v_federation RECORD;
    v_tenant UUID;
BEGIN
    SELECT * INTO v_federation FROM tenant_federation 
    WHERE federation_id = p_federation_id AND is_active = TRUE;
    
    IF v_federation IS NULL THEN
        RETURN QUERY SELECT '{"error": "Federation not found"}'::JSONB;
        RETURN;
    END IF;
    
    -- Execute for each member tenant
    FOREACH v_tenant IN ARRAY v_federation.member_tenants
    LOOP
        PERFORM set_config('surypus.tenant_id', v_tenant::TEXT, TRUE);
        RETURN QUERY EXECUTE p_sql;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Tenant replication status
CREATE TABLE IF NOT EXISTS tenant_replication (
    source_tenant_id UUID,
    target_tenant_id UUID,
    replication_type TEXT CHECK (replication_type IN ('full', 'incremental', 'snapshot')),
    status TEXT CHECK (status IN ('idle', 'syncing', 'synced', 'error')),
    last_sync_at TIMESTAMPTZ,
    lag_seconds INT DEFAULT 0,
    PRIMARY KEY(source_tenant_id, target_tenant_id)
);

-- Replication sync function
CREATE OR REPLACE FUNCTION sync_tenant_data(
    p_source_tenant UUID,
    p_target_tenant UUID,
    p_replication_type TEXT DEFAULT 'incremental'
) RETURNS VOID AS $$
BEGIN
    UPDATE tenant_replication SET 
        status = 'syncing',
        last_sync_at = NOW()
    WHERE source_tenant_id = p_source_tenant AND target_tenant_id = p_target_tenant;
    
    IF p_replication_type = 'full' THEN
        -- Full sync logic
        NULL;
    ELSIF p_replication_type = 'incremental' THEN
        -- Incremental sync via CDC
        NULL;
    END IF;
    
    UPDATE tenant_replication SET 
        status = 'synced',
        lag_seconds = EXTRACT(EPOCH FROM (NOW() - last_sync_at))::INT
    WHERE source_tenant_id = p_source_tenant AND target_tenant_id = p_target_tenant;
END;
$$ LANGUAGE plpgsql;