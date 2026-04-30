-- ============================================================================
-- Advanced Real-Time Collaboration
-- ============================================================================

-- Presence tracking
CREATE TABLE IF NOT EXISTS user_presence (
    user_id UUID REFERENCES users(user_id),
    tenant_id UUID REFERENCES tenants(tenant_id),
    current_page TEXT,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    is_online BOOLEAN DEFAULT TRUE,
    PRIMARY KEY(user_id, tenant_id)
);

-- Real-time cursors
CREATE TABLE IF NOT EXISTS collaborative_cursors (
    id BIGSERIAL PRIMARY KEY,
    document_id TEXT NOT NULL,
    user_id UUID REFERENCES users(user_id),
    cursor_position JSONB,
    selection_range JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Document locks
CREATE TABLE IF NOT EXISTS document_locks (
    document_id TEXT PRIMARY KEY,
    user_id UUID REFERENCES users(user_id),
    lock_type TEXT CHECK (lock_type IN ('edit', 'view', 'comment')),
    acquired_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Update presence
CREATE OR REPLACE FUNCTION update_presence(
    p_user_id UUID,
    p_tenant_id UUID,
    p_current_page TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO user_presence (user_id, tenant_id, current_page)
    VALUES (p_user_id, p_tenant_id, p_current_page)
    ON CONFLICT (user_id, tenant_id) DO UPDATE SET
        current_page = p_current_page,
        last_seen_at = NOW(),
        is_online = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Get online users
CREATE OR REPLACE FUNCTION get_online_users(p_tenant_id UUID)
RETURNS TABLE(user_id UUID, current_page TEXT, last_seen_at TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY
    SELECT up.user_id, up.current_page, up.last_seen_at
    FROM user_presence up
    WHERE up.tenant_id = p_tenant_id AND up.is_online = TRUE
      AND up.last_seen_at > NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;