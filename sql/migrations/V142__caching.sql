-- Query result cache table
CREATE TABLE IF NOT EXISTS query_cache (
    cache_key TEXT PRIMARY KEY,
    result JSONB,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Cache lookup function
CREATE OR REPLACE FUNCTION cache_get(p_key TEXT) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT result INTO v_result
    FROM query_cache
    WHERE cache_key = p_key AND (expires_at IS NULL OR expires_at > NOW());
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Cache set function
CREATE OR REPLACE FUNCTION cache_set(
    p_key TEXT,
    p_value JSONB,
    p_ttl_seconds INT DEFAULT 300
) RETURNS VOID AS $$
BEGIN
    INSERT INTO query_cache (cache_key, result, expires_at)
    VALUES (p_key, p_value, NOW() + (p_ttl_seconds || ' seconds')::INTERVAL)
    ON CONFLICT (cache_key) DO UPDATE SET
        result = p_value,
        expires_at = NOW() + (p_ttl_seconds || ' seconds')::INTERVAL,
        created_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Cache cleanup
CREATE OR REPLACE FUNCTION cache_cleanup() RETURNS INT AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM query_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;