-- ============================================================================
-- Workflow Engine
-- ============================================================================

-- Workflow definitions
CREATE TABLE IF NOT EXISTS workflows (
    id SERIAL PRIMARY KEY,
    workflow_name TEXT UNIQUE NOT NULL,
    description TEXT,
    definition JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow instances
CREATE TABLE IF NOT EXISTS workflow_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_name TEXT NOT NULL,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')) DEFAULT 'pending',
    current_step INT DEFAULT 0,
    context JSONB DEFAULT '{}',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Start workflow
CREATE OR REPLACE FUNCTION workflow_start(
    p_workflow_name TEXT,
    p_initial_context JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    v_instance_id UUID;
BEGIN
    INSERT INTO workflow_instances (workflow_name, context, status)
    VALUES (p_workflow_name, p_initial_context, 'running')
    RETURNING id INTO v_instance_id;
    
    RETURN v_instance_id;
END;
$$ LANGUAGE plpgsql;

-- Complete workflow step
CREATE OR REPLACE FUNCTION workflow_step_complete(
    p_instance_id UUID,
    p_next_step INT,
    p_context JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE workflow_instances 
    SET current_step = p_next_step,
        context = COALESCE(p_context, context) || p_context
    WHERE id = p_instance_id;
END;
$$ LANGUAGE plpgsql;

-- Complete workflow
CREATE OR REPLACE FUNCTION workflow_complete(p_instance_id UUID) RETURNS VOID AS $$
BEGIN
    UPDATE workflow_instances 
    SET status = 'completed', completed_at = NOW()
    WHERE id = p_instance_id;
END;
$$ LANGUAGE plpgsql;