-- ============================================================================
-- Advanced Rate Limiting: API & Query
-- ============================================================================

-- Rate limit configuration
CREATE TABLE IF NOT EXISTS rate_limit_config (
    id SERIAL PRIMARY KEY,
    limit_key TEXT UNIQUE NOT NULL,
    limit_type TEXT CHECK (limit_type IN ('user', 'tenant', 'ip', 'global')),
    action TEXT NOT NULL,
    max_requests INT NOT NULL,
    window_seconds INT NOT NULL,
    description TEXT
);

-- Default rate limits
INSERT INTO rate_limit_config (limit_key, limit_type, action, max_requests, window_seconds, description)
VALUES 
    ('api_event_append', 'user', 'event_append', 1000, 60, 'Event append per user per minute'),
    ('api_tenant_events', 'tenant', 'event_append', 10000, 60, 'Events per tenant per minute'),
    ('api_query', 'user', 'query', 500, 60, 'Read queries per user per minute'),
    ('api_mutation', 'user', 'mutation', 200, 60, 'Write operations per user per minute'),
    ('ip_events', 'ip', 'event_append', 5000, 60, 'Events per IP per minute')
ON CONFLICT (limit_key) DO NOTHING;

-- Rate limit check with config
CREATE OR REPLACE FUNCTION check_rate_limit_advanced(
    p_identifier TEXT,
    p_limit_type TEXT,
    p_action TEXT,
    p_window_seconds INT DEFAULT 60,
    p_max_requests INT DEFAULT 100
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_count INT;
    v_window_start TIMESTAMP;
BEGIN
    SELECT count, window_start INTO v_current_count, v_window_start
    FROM rate_limits
    WHERE identifier = p_identifier AND action = p_action
    FOR UPDATE;
    
    IF v_current_count IS NULL THEN
        INSERT INTO rate_limits (identifier, action, count, window_start)
        VALUES (p_identifier, p_action, 1, NOW())
        ON CONFLICT (identifier, action) DO UPDATE SET count = 1, window_start = NOW();
        RETURN TRUE;
    END IF;
    
    -- Reset if window expired
    IF v_window_start + (p_window_seconds || ' seconds')::INTERVAL < NOW() THEN
        UPDATE rate_limits SET count = 1, window_start = NOW()
        WHERE identifier = p_identifier AND action = p_action;
        RETURN TRUE;
    END IF;
    
    -- Check limit
    IF v_current_count >= p_max_requests THEN
        PERFORM metrics_record('rate_limit_exceeded', 1, 
            jsonb_build_object('identifier', p_identifier, 'action', p_action));
        RETURN FALSE;
    END IF;
    
    UPDATE rate_limits SET count = count + 1
    WHERE identifier = p_identifier AND action = p_action;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Rate limit by config lookup
CREATE OR REPLACE FUNCTION check_rate_limit_by_config(
    p_identifier TEXT,
    p_action TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_config RECORD;
    v_result BOOLEAN;
BEGIN
    -- Determine identifier type
    SELECT * INTO v_config
    FROM rate_limit_config
    WHERE action = p_action
      AND (limit_type = 'global' OR limit_key LIKE '%' || p_identifier || '%')
    LIMIT 1;
    
    IF v_config IS NULL THEN
        RETURN TRUE;  -- No limit configured
    END IF;
    
    v_result := check_rate_limit_advanced(
        p_identifier,
        v_config.limit_type,
        p_action,
        v_config.window_seconds,
        v_config.max_requests
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Rate limit stats
CREATE OR REPLACE FUNCTION rate_limit_stats() RETURNS TABLE(
    action TEXT,
    avg_requests NUMERIC,
    max_requests INT,
    limited_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rl.action,
        AVG(rl.count)::NUMERIC,
        MAX(rl.count),
        COUNT(*)::BIGINT
    FROM rate_limits rl
    WHERE rl.window_start > NOW() - INTERVAL '1 hour'
    GROUP BY rl.action;
END;
$$ LANGUAGE plpgsql;