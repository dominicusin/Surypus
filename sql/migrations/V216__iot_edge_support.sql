-- ============================================================================
-- IoT & Edge Computing Support
-- ============================================================================

-- Device registry
CREATE TABLE IF NOT EXISTS devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id),
    device_type TEXT NOT NULL,
    firmware_version TEXT,
    last_seen_at TIMESTAMPTZ,
    status TEXT CHECK (status IN ('online', 'offline', 'error', 'maintenance')) DEFAULT 'offline',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device telemetry
CREATE TABLE IF NOT EXISTS device_telemetry (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID REFERENCES devices(device_id),
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    unit TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    location JSONB
);

-- Edge computation results
CREATE TABLE IF NOT EXISTS edge_computations (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID REFERENCES devices(device_id),
    computation_type TEXT,
    input_data JSONB,
    output_data JSONB,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register device
CREATE OR REPLACE FUNCTION register_device(
    p_tenant_id UUID,
    p_device_type TEXT,
    p_metadata JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    v_device_id UUID;
BEGIN
    INSERT INTO devices (tenant_id, device_type, metadata)
    VALUES (p_tenant_id, p_device_type, p_metadata)
    RETURNING device_id INTO v_device_id;
    
    RETURN v_device_id;
END;
$$ LANGUAGE plpgsql;

-- Process telemetry
CREATE OR REPLACE FUNCTION process_telemetry(
    p_device_id UUID,
    p_metric_name TEXT,
    p_value NUMERIC,
    p_unit TEXT DEFAULT NULL,
    p_location JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO device_telemetry (device_id, metric_name, metric_value, unit, location)
    VALUES (p_device_id, p_metric_name, p_value, p_unit, p_location);
    
    UPDATE devices SET last_seen_at = NOW(), status = 'online'
    WHERE device_id = p_device_id;
END;
$$ LANGUAGE plpgsql;