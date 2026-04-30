-- ============================================================================
-- Advanced Digital Twin Support
-- ============================================================================

-- Digital twin definitions
CREATE TABLE IF NOT EXISTS digital_twins (
    twin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id),
    twin_type TEXT NOT NULL,
    physical_id TEXT NOT NULL,  -- Reference to physical entity
    state JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    last_sync_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Twin telemetry history
CREATE TABLE IF NOT EXISTS twin_telemetry (
    id BIGSERIAL PRIMARY KEY,
    twin_id UUID REFERENCES digital_twins(twin_id),
    telemetry_data JSONB NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Twin state synchronization
CREATE OR REPLACE FUNCTION sync_twin_state(
    p_twin_id UUID,
    p_new_state JSONB
) RETURNS VOID AS $$
BEGIN
    UPDATE digital_twins 
    SET state = p_new_state, last_sync_at = NOW()
    WHERE twin_id = p_twin_id;
    
    INSERT INTO twin_telemetry (twin_id, telemetry_data)
    VALUES (p_twin_id, p_new_state);
END;
$$ LANGUAGE plpgsql;

-- Get twin history
CREATE OR REPLACE FUNCTION get_twin_history(
    p_twin_id UUID,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
) RETURNS TABLE(recorded_at TIMESTAMPTZ, telemetry_data JSONB) AS $$
BEGIN
    RETURN QUERY
    SELECT tt.recorded_at, tt.telemetry_data
    FROM twin_telemetry tt
    WHERE tt.twin_id = p_twin_id
      AND tt.recorded_at BETWEEN p_from AND p_to
    ORDER BY tt.recorded_at;
END;
$$ LANGUAGE plpgsql;

-- Analyze twin trends
CREATE OR REPLACE FUNCTION analyze_twin_trends(
    p_twin_id UUID,
    p_metric_path TEXT,
    p_period INTERVAL DEFAULT INTERVAL '7 days'
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Simplified trend analysis
    v_result := jsonb_build_object(
        'metric', p_metric_path,
        'period', p_period,
        'analysis', 'time_series_trend'
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;