-- ============================================================================
-- Serverless Function Support
-- ============================================================================

-- Function registry
CREATE TABLE IF NOT EXISTS serverless_functions (
    id SERIAL PRIMARY KEY,
    function_name TEXT UNIQUE NOT NULL,
    function_body TEXT NOT NULL,
    language TEXT CHECK (language IN ('plpgsql', 'sql')),
    timeout_seconds INT DEFAULT 30,
    memory_mb INT DEFAULT 128,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function execution log
CREATE TABLE IF NOT EXISTS function_executions (
    id BIGSERIAL PRIMARY KEY,
    function_name TEXT NOT NULL,
    input_payload JSONB,
    output_payload JSONB,
    execution_time_ms INT,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Register sample function
INSERT INTO serverless_functions (function_name, function_body, language)
VALUES 
    ('hello_world', 'SELECT jsonb_build_object(''message'', ''Hello from serverless!'', ''timestamp'', NOW())', 'plpgsql'),
    ('process_event', 'SELECT jsonb_build_object(''processed'', TRUE, ''input'', $1)', 'plpgsql')
ON CONFLICT (function_name) DO NOTHING;

-- Execute serverless function
CREATE OR REPLACE FUNCTION execute_function(
    p_function_name TEXT,
    p_input JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB AS $$
DECLARE
    v_function serverless_functions%ROWTYPE;
    v_execution_id BIGINT;
    v_start_time TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    SELECT * INTO v_function FROM serverless_functions 
    WHERE function_name = p_function_name AND is_active = TRUE;
    
    IF v_function IS NULL THEN
        RETURN '{"error": "Function not found"}'::JSONB;
    END IF;
    
    v_start_time := clock_timestamp();
    
    INSERT INTO function_executions (function_name, input_payload, status, started_at)
    VALUES (p_function_name, p_input, 'running', v_start_time)
    RETURNING id INTO v_execution_id;
    
    BEGIN
        EXECUTE v_function.function_body INTO v_result;
        
        UPDATE function_executions 
        SET status = 'completed', output_payload = v_result, 
            execution_time_ms = EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000,
            completed_at = NOW()
        WHERE id = v_execution_id;
        
    EXCEPTION WHEN OTHERS THEN
        UPDATE function_executions 
        SET status = 'failed', error_message = SQLERRM,
            completed_at = NOW()
        WHERE id = v_execution_id;
        
        v_result := jsonb_build_object('error', SQLERRM);
    END;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;