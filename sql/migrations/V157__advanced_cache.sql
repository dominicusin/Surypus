-- ============================================================================
-- Advanced Caching Strategies
-- ============================================================================

-- Multi-tier cache: L1 (memory), L2 (DB), L3 (Redis-ready)
CREATE TABLE IF NOT EXISTS cache_tiers (
    tier_id SERIAL PRIMARY KEY,
    cache_key TEXT UNIQUE NOT NULL,
    l1_value JSONB,
    l2_value JSONB,
    l1_expires_at TIMESTAMP WITH TIME ZONE,
    l2_expires_at TIMESTAMP WITH TIME ZONE,
    hits INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Cache-aside pattern
CREATE OR REPLACE FUNCTION cache_get_or_set(
    p_key TEXT,
    p_factory_sql TEXT,
    p_ttl_l1 INT DEFAULT 60,
    p_ttl_l2 INT DEFAULT 3600
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_l1_expires TIMESTAMP;
    v_l2_expires TIMESTAMP;
BEGIN
    -- Check L1 cache
    SELECT l1_value, l1_expires_at INTO v_result, v_l1_expires
    FROM cache_tiers WHERE cache_key = p_key;
    
    IF v_result IS NOT NULL AND (v_l1_expires IS NULL OR v_l1_expires > NOW()) THEN
        UPDATE cache_tiers SET hits = hits + 1 WHERE cache_key = p_key;
        RETURN v_result;
    END IF;
    
    -- Check L2 cache
    SELECT l2_value, l2_expires_at INTO v_result, v_l2_expires
    FROM cache_tiers WHERE cache_key = p_key;
    
    IF v_result IS NOT NULL AND (v_l2_expires IS NULL OR v_l2_expires > NOW()) THEN
        UPDATE cache_tiers SET l1_value = v_result, l1_expires_at = NOW() + (p_ttl_l1 || ' seconds')::INTERVAL,
            hits = hits + 1 WHERE cache_key = p_key;
        RETURN v_result;
    END IF;
    
    -- Cache miss: execute factory
    EXECUTE p_factory_sql INTO v_result;
    
    -- Store in cache
    INSERT INTO cache_tiers (cache_key, l1_value, l2_value, l1_expires_at, l2_expires_at)
    VALUES (p_key, v_result, v_result, 
        NOW() + (p_ttl_l1 || ' seconds')::INTERVAL,
        NOW() + (p_ttl_l2 || ' seconds')::INTERVAL)
    ON CONFLICT (cache_key) DO UPDATE SET
        l1_value = v_result, l2_value = v_result,
        l1_expires_at = NOW() + (p_ttl_l1 || ' seconds')::INTERVAL,
        l2_expires_at = NOW() + (p_ttl_l2 || ' seconds')::INTERVAL,
        updated_at = NOW();
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Cache warming
CREATE OR REPLACE FUNCTION cache_warm(
    p_queries JSONB
) RETURNS INT AS $$
DECLARE
    v_query JSONB;
    v_count INT := 0;
BEGIN
    FOR v_query IN SELECT * FROM jsonb_array_elements(p_queries)
    LOOP
        PERFORM cache_get_or_set(
            v_query->>'key',
            v_query->>'sql',
            (v_query->>'ttl_l1')::INT,
            (v_query->>'ttl_l2')::INT
        );
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;