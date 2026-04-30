-- Safe dynamic SQL execution with allowlist validation
CREATE OR REPLACE FUNCTION safe_execute(
    p_function_name TEXT,
    p_args JSONB DEFAULT '{}'
) RETURNS JSONB AS $$
DECLARE
    v_allowed_functions TEXT[] := ARRAY[
        'proj_test_handler', 'projection_fifo_lots', 'projection_stock_balance'
    ];
    v_result JSONB;
BEGIN
    -- Validate function allowlist
    IF p_function_name <> ALL (v_allowed_functions) THEN
        RAISE EXCEPTION 'Function not allowed: %', p_function_name;
    END IF;
    
    -- Execute safely via format with identifier validation
    EXECUTE format('SELECT %I($1)', p_function_name) USING p_args INTO v_result;
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Safe execute failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Input validation for dynamic handlers
CREATE OR REPLACE FUNCTION validate_json_keys(
    p_data JSONB,
    p_required_keys TEXT[]
) RETURNS BOOLEAN AS $$
DECLARE
    v_key TEXT;
BEGIN
    FOREACH v_key IN ARRAY p_required_keys
    LOOP
        IF NOT (p_data ? v_key) THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;