-- ============================================================================
-- Advanced API Developer Portal
-- ============================================================================

-- API documentation
CREATE TABLE IF NOT EXISTS api_docs (
    id SERIAL PRIMARY KEY,
    api_version TEXT NOT NULL,
    endpoint_path TEXT NOT NULL,
    http_method TEXT NOT NULL,
    description TEXT,
    request_schema JSONB,
    response_schema JSONB,
    rate_limit JSONB,
    authentication_required BOOLEAN DEFAULT TRUE,
    is_deprecated BOOLEAN DEFAULT FALSE
);

-- Developer applications
CREATE TABLE IF NOT EXISTS developer_apps (
    id SERIAL PRIMARY KEY,
    app_name TEXT NOT NULL,
    developer_id UUID REFERENCES users(user_id),
    app_key TEXT UNIQUE NOT NULL,
    app_secret_hash TEXT,
    scopes TEXT[],
    status TEXT CHECK (status IN ('active', 'suspended', 'pending')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- API usage by developer
CREATE TABLE IF NOT EXISTS developer_usage (
    id BIGSERIAL PRIMARY KEY,
    app_id INT REFERENCES developer_apps(id),
    endpoint TEXT,
    http_status INT,
    response_time_ms INT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register API doc
CREATE OR REPLACE FUNCTION register_api_doc(
    p_version TEXT,
    p_path TEXT,
    p_method TEXT,
    p_description TEXT
) RETURNS INT AS $$
DECLARE
    v_doc_id INT;
BEGIN
    INSERT INTO api_docs (api_version, endpoint_path, http_method, description)
    VALUES (p_version, p_path, p_method, p_description)
    RETURNING id INTO v_doc_id;
    RETURN v_doc_id;
END;
$$ LANGUAGE plpgsql;