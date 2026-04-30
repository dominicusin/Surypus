-- ============================================================================
-- Advanced Caching: Redis-Ready Pattern with Invalidation
-- ============================================================================

-- Cache invalidation log
CREATE TABLE IF NOT EXISTS cache_invalidation_log (
    id SERIAL PRIMARY KEY,
    cache_key TEXT NOT NULL,
    invalidation_reason TEXT,
    caused_by_key TEXT,
    invalidated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Cache version tracking
CREATE TABLE IF NOT EXISTS cache_versions (
    key_prefix TEXT PRIMARY KEY,
    version INT DEFAULT 1,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Write-through cache update
CREATE OR REPLACE FUNCTION cache_write_through(
    p_key TEXT,
    p_value JSONB,
    p_related_keys TEXT[] DEFAULT '{}',
    p_ttl_l1 INT DEFAULT 60,
    p_ttl_l2 INT DEFAULT 3600
) RETURNS VOID AS $$
BEGIN
    -- Update main cache
    PERFORM cache_set(p_key, p_value, p_ttl_l1);
    
    -- Update version
    INSERT INTO cache_versions (key_prefix, version)
    VALUES (p_key, 1)
    ON CONFLICT (key_prefix) DO UPDATE SET
        version = cache_versions.version + 1,
        updated_at = NOW();
    
    -- Log invalidation of related keys
    PERFORM cache_invalidate(r) FROM unnest(p_related_keys) r;
END;
$$ LANGUAGE plpgsql;

-- Cache invalidation with cascade
CREATE OR REPLACE FUNCTION cache_invalidate(
    p_key TEXT,
    p_reason TEXT DEFAULT NULL,
    p_caused_by_key TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    DELETE FROM cache_tiers WHERE cache_key = p_key;
    
    INSERT INTO cache_invalidation_log (cache_key, invalidation_reason, caused_by_key)
    VALUES (p_key, p_reason, p_caused_by_key);
END;
$$ LANGUAGE plpgsql;

-- Cache by tenant (multi-tenant aware)
CREATE OR REPLACE FUNCTION cache_get_tenant(
    p_tenant_id UUID,
    p_key TEXT
) RETURNS JSONB AS $$
DECLARE
    v_full_key TEXT;
BEGIN
    v_full_key := p_tenant_id::TEXT || ':' || p_key;
    RETURN cache_get(v_full_key);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cache_set_tenant(
    p_tenant_id UUID,
    p_key TEXT,
    p_value JSONB,
    p_ttl_seconds INT DEFAULT 300
) RETURNS VOID AS $$
DECLARE
    v_full_key TEXT;
BEGIN
    v_full_key := p_tenant_id::TEXT || ':' || p_key;
    PERFORM cache_set(v_full_key, p_value, p_ttl_seconds);
END;
$$ LANGUAGE plpgsql;

-- Cache stats
CREATE OR REPLACE FUNCTION cache_stats() RETURNS TABLE(
    metric_name TEXT,
    metric_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'total_keys'::TEXT, COUNT(*)::BIGINT FROM cache_tiers
    UNION ALL
    SELECT 'l1_hits'::TEXT, SUM(hits)::BIGINT FROM cache_tiers WHERE l1_expires_at > NOW()
    UNION ALL
    SELECT 'expired_keys'::TEXT, COUNT(*)::BIGINT FROM cache_tiers WHERE l2_expires_at < NOW();
END;
$$ LANGUAGE plpgsql;