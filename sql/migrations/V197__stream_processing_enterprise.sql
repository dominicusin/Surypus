-- ============================================================================
-- Enterprise Stream Processing: Event Processing Pipelines
-- ============================================================================

-- Stream pipeline definitions
CREATE TABLE IF NOT EXISTS stream_pipelines (
    id SERIAL PRIMARY KEY,
    pipeline_name TEXT UNIQUE NOT NULL,
    source_stream TEXT NOT NULL,
    processors JSONB NOT NULL,  -- Array of processor configs
    output_stream TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline execution
CREATE TABLE IF NOT EXISTS pipeline_executions (
    id BIGSERIAL PRIMARY KEY,
    pipeline_name TEXT NOT NULL,
    status TEXT CHECK (status IN ('started', 'running', 'paused', 'completed', 'failed')) DEFAULT 'started',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    events_processed INT DEFAULT 0,
    errors_count INT DEFAULT 0
);

-- Pipeline step processor
CREATE OR REPLACE FUNCTION process_pipeline_step(
    p_pipeline_name TEXT,
    p_event_data JSONB,
    p_step_index INT
) RETURNS JSONB AS $$
DECLARE
    v_pipeline RECORD;
    v_processor JSONB;
    v_result JSONB;
BEGIN
    SELECT * INTO v_pipeline FROM stream_pipelines WHERE pipeline_name = p_pipeline_name AND is_active = TRUE;
    
    IF v_pipeline IS NULL THEN
        RETURN p_event_data;
    END IF;
    
    v_processor := v_pipeline.processors->p_step_index;
    v_result := p_event_data;
    
    -- Apply processor (simplified)
    IF v_processor->>'type' = 'filter' THEN
        IF NOT (v_result @> (v_processor->>'condition')) THEN
            RETURN NULL;
        END IF;
    ELSIF v_processor->>'type' = 'transform' THEN
        v_result := v_result || (v_processor->>'mapping')::JSONB;
    ELSIF v_processor->>'type' = 'aggregate' THEN
        -- Aggregation logic
        NULL;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Run pipeline
CREATE OR REPLACE FUNCTION run_pipeline(
    p_pipeline_name TEXT,
    p_batch_size INT DEFAULT 1000
) RETURNS INT AS $$
DECLARE
    v_execution_id BIGINT;
    v_processed INT := 0;
    v_event RECORD;
BEGIN
    INSERT INTO pipeline_executions (pipeline_name, status)
    VALUES (p_pipeline_name, 'running')
    RETURNING id INTO v_execution_id;
    
    -- Process events
    FOR v_event IN 
        SELECT * FROM cdc_log 
        ORDER BY id LIMIT p_batch_size
    LOOP
        BEGIN
            v_processed := v_processed + 1;
        EXCEPTION WHEN OTHERS THEN
            UPDATE pipeline_executions SET errors_count = errors_count + 1 WHERE id = v_execution_id;
        END;
    END LOOP;
    
    UPDATE pipeline_executions 
    SET status = 'completed', completed_at = NOW(), events_processed = v_processed
    WHERE id = v_execution_id;
    
    RETURN v_processed;
END;
$$ LANGUAGE plpgsql;