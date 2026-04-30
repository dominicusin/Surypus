-- ============================================================================
-- Distributed Cache with Redis Pattern
-- ============================================================================

-- Cache node configuration
CREATE TABLE IF NOT EXISTS cache_nodes (
    node_id SERIAL PRIMARY KEY,
    node_name TEXT UNIQUE NOT NULL,
    node_type TEXT CHECK (node_type IN ('memory', 'disk', 'redis')),
    max_memory_mb INT DEFAULT 1024,
    is_active BOOLEAN DEFAULT TRUE,
    last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Distributed lock
CREATE TABLE IF NOT EXISTS distributed_locks (
    lock_key TEXT PRIMARY KEY,
    node_id INT REFERENCES cache_nodes(node_id),
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    owner_token TEXT
);

-- Acquire distributed lock
CREATE OR REPLACE FUNCTION acquire_lock(
    p_lock_key TEXT,
    p_owner_token TEXT,
    p_ttl_seconds INT DEFAULT 30
) RETURNS BOOLEAN AS $$
DECLARE
    v_acquired BOOLEAN := FALSE;
BEGIN
    -- Try to acquire
    INSERT INTO distributed_locks (lock_key, owner_token, expires_at)
    VALUES (p_lock_key, p_owner_token, NOW() + (p_ttl_seconds || ' seconds')::INTERVAL)
    ON CONFLICT (lock_key) DO 
    UPDATE SET node_id = EXCLUDED.node_id,
               acquired_at = NOW(),
               expires_at = EXCLUDED.expires_at,
               owner_token = EXCLUDED.owner_token
    WHERE distributed_locks.expires_at < NOW()
       OR distributed_locks.owner_token = EXCLUDED.owner_token;
    
    GET DIAGNOSTICS v_acquired = ROW_COUNT;
    RETURN v_acquired > 0;
END;
$$ LANGUAGE plpgsql;

-- Release distributed lock
CREATE OR REPLACE FUNCTION release_lock(
    p_lock_key TEXT,
    p_owner_token TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM distributed_locks 
    WHERE lock_key = p_lock_key AND owner_token = p_owner_token;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Cache tag system
CREATE TABLE IF NOT EXISTS cache_tags (
    tag_id SERIAL PRIMARY KEY,
    tag_name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cache_tag_mapping (
    cache_key TEXT REFERENCES cache_tiers(cache_key) ON DELETE CASCADE,
    tag_id INT REFERENCES cache_tags(tag_id) ON DELETE CASCADE,
    PRIMARY KEY (cache_key, tag_id)
);

-- Invalidate by tag
CREATE OR REPLACE FUNCTION invalidate_by_tag(p_tag_name TEXT) RETURNS INT AS $$
DECLARE
    v_deleted INT := 0;
BEGIN
    DELETE FROM cache_tiers
    WHERE cache_key IN (
        SELECT ct.cache_key FROM cache_tiers ct
        JOIN cache_tag_mapping ctm ON ct.cache_key = ctm.cache_key
        JOIN cache_tags ctg ON ctm.tag_id = ctg.tag_id
        WHERE ctg.tag_name = p_tag_name
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;