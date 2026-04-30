-- ============================================================================
-- Advanced Real-Time Analytics
-- ============================================================================

-- Streaming aggregations
CREATE TABLE IF NOT EXISTS streaming_aggregations (
    id SERIAL PRIMARY KEY,
    aggregation_name TEXT UNIQUE NOT NULL,
    source_stream TEXT NOT NULL,
    group_by_fields JSONB NOT NULL,
    aggregate_functions JSONB NOT NULL,  -- {"count": "COUNT(*)", "sum": "SUM(amount)"}
    window_type TEXT CHECK (window_type IN ('tumbling', 'hopping', 'session')),
    window_size INTERVAL NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Aggregated results
CREATE TABLE IF NOT EXISTS streaming_results (
    id BIGSERIAL PRIMARY KEY,
    aggregation_id INT REFERENCES streaming_aggregations(id),
    group_keys JSONB NOT NULL,
    results JSONB NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Real-time KPI tracking
CREATE TABLE IF NOT EXISTS kpi_tracking (
    id SERIAL PRIMARY KEY,
    kpi_name TEXT UNIQUE NOT NULL,
    kpi_definition JSONB NOT NULL,
    target_value NUMERIC,
    current_value NUMERIC,
    trend TEXT CHECK (trend IN ('up', 'down', 'stable')),
    last_calculated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Calculate KPI
CREATE OR REPLACE FUNCTION calculate_kpi(
    p_kpi_name TEXT
) RETURNS VOID AS $$
DECLARE
    v_kpi RECORD;
    v_value NUMERIC;
BEGIN
    SELECT * INTO v_kpi FROM kpi_tracking WHERE kpi_name = p_kpi_name;
    
    -- Simplified calculation
    v_value := (SELECT COUNT(*) FROM event_store);
    
    UPDATE kpi_tracking SET 
        current_value = v_value,
        trend = CASE 
            WHEN v_value > v_kpi.current_value THEN 'up'
            WHEN v_value < v_kpi.current_value THEN 'down'
            ELSE 'stable'
        END,
        last_calculated_at = NOW()
    WHERE kpi_name = p_kpi_name;
END;
$$ LANGUAGE plpgsql;