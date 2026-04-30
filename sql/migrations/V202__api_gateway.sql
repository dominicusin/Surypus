-- ============================================================================
-- API Gateway Functions
-- ============================================================================

-- API endpoint configuration
CREATE TABLE IF NOT EXISTS api_endpoints (
    id SERIAL PRIMARY KEY,
    endpoint_path TEXT UNIQUE NOT NULL,
    http_method TEXT CHECK (http_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE')),
    handler_function TEXT NOT NULL,
    rate_limit_override INT,
    auth_required BOOLEAN DEFAULT TRUE,
    cache_enabled BOOLEAN DEFAULT FALSE,
    cache_ttl_seconds INT DEFAULT 60,
    is_active BOOLEAN DEFAULT TRUE
);

-- Register endpoints
INSERT INTO api_endpoints (endpoint_path, http_method, handler_function, auth_required)
VALUES 
    ('/api/v2/events', 'POST', 'event_append', TRUE),
    ('/api/v2/events', 'GET', 'event_get_by_aggregate', TRUE),
    ('/api/v2/projections', 'GET', 'projection_get_all', FALSE),
    ('/api/v2/health', 'GET', 'health_record', FALSE)
ON CONFLICT (endpoint_path) DO NOTHING;

-- Request router
CREATE OR REPLACE FUNCTION api_route(
    p_path TEXT,
    p_method TEXT,
    p_headers JSONB DEFAULT '{}',
    p_body JSONB DEFAULT NULL
) RETURNS TABLE(status_code INT, response_body JSONB, headers JSONB) AS $$
DECLARE
    v_endpoint RECORD;
    v_result JSONB;
    v_status INT := 200;
BEGIN
    SELECT * INTO v_endpoint 
    FROM api_endpoints 
    WHERE endpoint_path = p_path AND http_method = p_method AND is_active = TRUE;
    
    IF v_endpoint IS NULL THEN
        RETURN QUERY SELECT 404, '{"error": "Not Found"}'::JSONB, '{}'::JSONB;
        RETURN;
    END IF;
    
    -- Rate limit check
    IF v_endpoint.rate_limit_override IS NOT NULL THEN
        IF NOT check_rate_limit_by_config((p_headers->>'user_id')::TEXT, v_endpoint.endpoint_path) THEN
            RETURN QUERY SELECT 429, '{"error": "Rate limit exceeded"}'::JSONB, '{}'::JSONB;
            RETURN;
        END IF;
    END IF;
    
    -- Execute handler
    BEGIN
        EXECUTE format('SELECT %I($1, $2)', v_endpoint.handler_function) 
        USING p_headers, COALESCE(p_body, '{}'::JSONB)
        INTO v_result;
    EXCEPTION WHEN OTHERS THEN
        v_result := jsonb_build_object('error', SQLERRM);
        v_status := 500;
    END;
    
    RETURN QUERY SELECT v_status, v_result, '{}'::JSONB;
END;
$$ LANGUAGE plpgsql;