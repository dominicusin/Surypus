-- ============================================================================
-- Advanced Data Pipeline Orchestration
-- ============================================================================

-- Pipeline definitions
CREATE TABLE IF NOT EXISTS pipelines (
    id SERIAL PRIMARY KEY,
    pipeline_name TEXT UNIQUE NOT NULL,
    pipeline_type TEXT CHECK (pipeline_type IN ('etl', 'elt', 'streaming', 'batch')),
    stages JSONB NOT NULL,
    retry_policy JSONB DEFAULT '{"max_retries": 3, "backoff": "exponential"}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pipeline executions
CREATE TABLE IF NOT EXISTS pipeline_executions_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id INT REFERENCES pipelines(id),
    status TEXT CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
    current_stage INT DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT
);

-- Pipeline artifacts
CREATE TABLE IF NOT EXISTS pipeline_artifacts (
    id BIGSERIAL PRIMARY KEY,
    execution_id UUID REFERENCES pipeline_executions_v2(id),
    stage_name TEXT,
    artifact_type TEXT,
    artifact_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Execute pipeline
CREATE OR REPLACE FUNCTION execute_pipeline(
    p_pipeline_name TEXT
) RETURNS UUID AS $$
DECLARE
    v_pipeline RECORD;
    v_execution_id UUID;
BEGIN
    SELECT * INTO v_pipeline FROM pipelines WHERE pipeline_name = p_pipeline_name AND is_active = TRUE;
    
    INSERT INTO pipeline_executions_v2 (pipeline_id, status, current_stage)
    VALUES (v_pipeline.id, 'running', 0)
    RETURNING id INTO v_execution_id;
    
    RETURN v_execution_id;
END;
$$ LANGUAGE plpgsql;