-- ============================================================================
-- Advanced Reporting Engine
-- ============================================================================

-- Report definitions
CREATE TABLE IF NOT EXISTS report_definitions (
    id SERIAL PRIMARY KEY,
    report_name TEXT UNIQUE NOT NULL,
    report_type TEXT CHECK (report_type IN ('tabular', 'chart', 'pivot', 'dashboard')),
    query_template TEXT NOT NULL,
    parameters JSONB DEFAULT '[]',
    schedule TEXT,
    is_shared BOOLEAN DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report executions
CREATE TABLE IF NOT EXISTS report_executions (
    id BIGSERIAL PRIMARY KEY,
    report_id INT REFERENCES report_definitions(id),
    parameters JSONB,
    execution_time_ms INT,
    row_count INT,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Report subscriptions
CREATE TABLE IF NOT EXISTS report_subscriptions (
    id SERIAL PRIMARY KEY,
    report_id INT REFERENCES report_definitions(id),
    user_id UUID REFERENCES users(user_id),
    frequency TEXT CHECK (frequency IN ('daily', 'weekly', 'monthly')),
    delivery_channel TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Generate report
CREATE OR REPLACE FUNCTION generate_report(
    p_report_name TEXT,
    p_parameters JSONB DEFAULT '{}'
) RETURNS TABLE(result JSONB) AS $$
DECLARE
    v_report RECORD;
    v_execution_id BIGINT;
    v_start_time TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_report FROM report_definitions WHERE report_name = p_report_name;
    
    v_start_time := clock_timestamp();
    
    INSERT INTO report_executions (report_id, parameters, status)
    VALUES (v_report.id, p_parameters, 'running')
    RETURNING id INTO v_execution_id;
    
    RETURN QUERY EXECUTE v_report.query_template;
    
    UPDATE report_executions SET 
        status = 'completed',
        execution_time_ms = EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000,
        completed_at = NOW()
    WHERE id = v_execution_id;
END;
$$ LANGUAGE plpgsql;