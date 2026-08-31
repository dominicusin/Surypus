-- ============================================================================
-- Advanced Security Features
-- ============================================================================

-- Session management
CREATE TABLE IF NOT EXISTS active_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id),
    tenant_id UUID REFERENCES tenants(tenant_id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    is_revoked BOOLEAN DEFAULT FALSE
);

-- Session refresh
CREATE OR REPLACE FUNCTION refresh_session(
    p_session_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_session active_sessions%ROWTYPE;
BEGIN
    SELECT * INTO v_session FROM active_sessions 
    WHERE session_id = p_session_id AND is_revoked = FALSE;
    
    IF v_session IS NULL OR v_session.expires_at < NOW() THEN
        RETURN FALSE;
    END IF;
    
    UPDATE active_sessions SET last_activity_at = NOW()
    WHERE session_id = p_session_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- OAuth2 provider support (simplified)
CREATE TABLE IF NOT EXISTS oauth_clients (
    id SERIAL PRIMARY KEY,
    client_id TEXT UNIQUE NOT NULL,
    client_secret_hash TEXT NOT NULL,
    tenant_id UUID REFERENCES tenants(tenant_id),
    redirect_uris TEXT[],
    granted_scopes TEXT[],
    is_active BOOLEAN DEFAULT TRUE
);

-- Token generation
CREATE OR REPLACE FUNCTION generate_oauth_token(
    p_client_id TEXT,
    p_grant_type TEXT,
    p_scopes TEXT[]
) RETURNS JSONB AS $$
DECLARE
    v_client RECORD;
    v_access_token TEXT;
    v_refresh_token TEXT;
BEGIN
    SELECT * INTO v_client FROM oauth_clients 
    WHERE client_id = p_client_id AND is_active = TRUE;
    
    IF v_client IS NULL THEN
        RETURN '{"error": "invalid_client"}'::JSONB;
    END IF;
    
    v_access_token := encode(gen_random_bytes(32), 'base64');
    v_refresh_token := encode(gen_random_bytes(32), 'base64');
    
    RETURN jsonb_build_object(
        'access_token', v_access_token,
        'refresh_token', v_refresh_token,
        'token_type', 'Bearer',
        'expires_in', 3600
    );
END;
$$ LANGUAGE plpgsql;