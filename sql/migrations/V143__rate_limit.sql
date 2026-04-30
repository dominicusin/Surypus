-- Rate limiting table
CREATE TABLE IF NOT EXISTS rate_limits (
    rate_id BIGSERIAL PRIMARY KEY,
    identifier TEXT NOT NULL,  -- user_id, ip, tenant_id
    action TEXT NOT NULL,       -- event_append, cmd_inventory, etc.
    count INT DEFAULT 0,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    window_duration INTERVAL DEFAULT '1 minute',
    UNIQUE(identifier, action)
);

-- Check rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_identifier TEXT,
    p_action TEXT,
    p_limit INT DEFAULT 100
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_count INT;
    v_window_start TIMESTAMP WITH TIME ZONE;
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
    
    IF v_window_start + INTERVAL '1 minute' < NOW() THEN
        UPDATE rate_limits SET count = 1, window_start = NOW()
        WHERE identifier = p_identifier AND action = p_action;
        RETURN TRUE;
    END IF;
    
    IF v_current_count >= p_limit THEN
        RETURN FALSE;
    END IF;
    
    UPDATE rate_limits SET count = count + 1
    WHERE identifier = p_identifier AND action = p_action;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;