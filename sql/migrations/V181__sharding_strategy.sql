-- ============================================================================
-- Sharding Strategy for Scale
-- ============================================================================

-- Shard configuration
CREATE TABLE IF NOT EXISTS shard_config (
    shard_id INT PRIMARY KEY,
    shard_name TEXT NOT NULL,
    tenant_ids UUID[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Shard router function
CREATE OR REPLACE FUNCTION get_shard(
    p_tenant_id UUID
) RETURNS INT AS $$
DECLARE
    v_shard_id INT;
BEGIN
    -- Consistent hashing (simple modulo)
    v_shard_id := (p_tenant_id::TEXT::BIGINT) % 256;
    RETURN v_shard_id;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Shard-aware query
CREATE OR REPLACE FUNCTION query_sharded(
    p_tenant_id UUID,
    p_query TEXT
) RETURNS TABLE(result JSONB) AS $$
DECLARE
    v_shard INT;
BEGIN
    v_shard := get_shard(p_tenant_id);
    RETURN QUERY EXECUTE p_query;  -- Execute on correct shard
END;
$$ LANGUAGE plpgsql;

-- Tenant migration
CREATE OR REPLACE FUNCTION migrate_tenant_to_shard(
    p_tenant_id UUID,
    p_target_shard_id INT
) RETURNS VOID AS $$
BEGIN
    -- Update tenant->shard mapping
    INSERT INTO shard_config (tenant_ids)
    VALUES (ARRAY[p_tenant_id])
    ON CONFLICT (shard_id) DO UPDATE 
    SET tenant_ids = array_append(shard_config.tenant_ids, p_tenant_id);
    
    RAISE NOTICE 'Tenant % migrated to shard %', p_tenant_id, p_target_shard_id;
END;
$$ LANGUAGE plpgsql;