-- ============================================================================
-- Advanced Observability Stack
-- ============================================================================

-- Service catalog
CREATE TABLE IF NOT EXISTS service_catalog (
    id SERIAL PRIMARY KEY,
    service_name TEXT UNIQUE NOT NULL,
    service_type TEXT CHECK (service_type IN ('api', 'worker', 'scheduler', 'processor')),
    owner_team TEXT,
    repository_url TEXT,
    documentation_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Service dependencies
CREATE TABLE IF NOT EXISTS service_dependencies (
    id BIGSERIAL PRIMARY KEY,
    from_service_id INT REFERENCES service_catalog(id),
    to_service_id INT REFERENCES service_catalog(id),
    dependency_type TEXT CHECK (dependency_type IN ('hard', 'soft', 'eventual'))
);

-- Service health history
CREATE TABLE IF NOT EXISTS service_health_history (
    id BIGSERIAL PRIMARY KEY,
    service_id INT REFERENCES service_catalog(id),
    status TEXT CHECK (status IN ('healthy', 'degraded', 'down')),
    response_time_ms INT,
    error_rate FLOAT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register service
CREATE OR REPLACE FUNCTION register_service(
    p_service_name TEXT,
    p_service_type TEXT,
    p_owner_team TEXT
) RETURNS INT AS $$
DECLARE
    v_service_id INT;
BEGIN
    INSERT INTO service_catalog (service_name, service_type, owner_team)
    VALUES (p_service_name, p_service_type, p_owner_team)
    RETURNING id INTO v_service_id;
    RETURN v_service_id;
END;
$$ LANGUAGE plpgsql;

-- Record health
CREATE OR REPLACE FUNCTION record_service_health(
    p_service_name TEXT,
    p_status TEXT,
    p_response_time_ms INT,
    p_error_rate FLOAT
) RETURNS VOID AS $$
DECLARE
    v_service_id INT;
BEGIN
    SELECT id INTO v_service_id FROM service_catalog WHERE service_name = p_service_name;
    
    INSERT INTO service_health_history (service_id, status, response_time_ms, error_rate)
    VALUES (v_service_id, p_status, p_response_time_ms, p_error_rate);
END;
$$ LANGUAGE plpgsql;