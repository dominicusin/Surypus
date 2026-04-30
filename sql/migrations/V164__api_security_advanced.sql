-- ============================================================================
-- API Security Hardening
-- ============================================================================

-- API request validation
CREATE TABLE IF NOT EXISTS api_request_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    tenant_id UUID,
    api_endpoint TEXT NOT NULL,
    http_method TEXT,
    request_body JSONB,
    response_code INT,
    response_time_ms INT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_api_log_endpoint ON api_request_log(api_endpoint, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_log_user ON api_request_log(user_id, created_at DESC);

-- Input sanitization
CREATE OR REPLACE FUNCTION sanitize_input(
    p_input TEXT,
    p_input_type TEXT DEFAULT 'text'
) RETURNS TEXT AS $$
DECLARE
    v_sanitized TEXT;
BEGIN
    v_sanitized := p_input;
    
    -- SQL injection prevention
    IF p_input_type = 'sql' THEN
        v_sanitized := regexp_replace(v_sanitized, '''', '''''', 'g');
        v_sanitized := regexp_replace(v_sanitized, ';', '', 'g');
        v_sanitized := regexp_replace(v_sanitized, '--', '', 'g');
        v_sanitized := regexp_replace(v_sanitized, '/*', '', 'g');
        v_sanitized := regexp_replace(v_sanitized, '*/', '', 'g');
    END IF;
    
    -- XSS prevention
    IF p_input_type = 'html' THEN
        v_sanitized := regexp_replace(v_sanitized, '<script', '<_script', 'gi');
        v_sanitized := regexp_replace(v_sanitized, 'javascript:', 'javascript_', 'gi');
        v_sanitized := regexp_replace(v_sanitized, 'onerror=', 'onerror_=', 'gi');
    END IF;
    
    RETURN v_sanitized;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Parameterized query enforcer
CREATE OR REPLACE FUNCTION enforce_parameterized(
    p_query TEXT,
    p_params JSONB
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check for non-parameterized dynamic SQL
    IF p_query ~* 'execute|exec\s+sp' THEN
        RAISE EXCEPTION 'Dynamic execution not allowed';
    END IF;
    
    -- Ensure parameters are used
    IF jsonb_array_length(p_params) > 0 AND p_query !~ '\$1' THEN
        RAISE EXCEPTION 'Query must use parameterized values';
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- IP allowlist
CREATE TABLE IF NOT EXISTS ip_allowlist (
    id SERIAL PRIMARY KEY,
    tenant_id UUID,
    ip_address CIDR NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Check IP access
CREATE OR REPLACE FUNCTION check_ip_allowed(
    p_tenant_id UUID,
    p_ip_address INET
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM ip_allowlist
        WHERE tenant_id = p_tenant_id
          AND is_active = TRUE
          AND p_ip_address <<= ip_address
    );
END;
$$ LANGUAGE plpgsql;