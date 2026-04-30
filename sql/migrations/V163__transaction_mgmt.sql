-- ============================================================================
-- Transaction Management
-- ============================================================================

-- Transaction log for auditing
CREATE TABLE IF NOT EXISTS transaction_log (
    tx_id BIGINT PRIMARY KEY,
    user_id UUID,
    tenant_id UUID,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    status TEXT CHECK (status IN ('active', 'committed', 'rolled_back', 'failed')),
    operations_count INT DEFAULT 0,
    error_message TEXT
);

-- Savepoint wrapper
CREATE OR REPLACE FUNCTION with_savepoint(
    p_function_name TEXT,
    p_args JSONB DEFAULT '{}'
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_savepoint_name TEXT := 'sp_' || md5(random()::TEXT);
BEGIN
    EXECUTE format('SAVEPOINT %I', v_savepoint_name);
    
    BEGIN
        EXECUTE format('SELECT %I($1)', p_function_name) USING p_args INTO v_result;
        EXECUTE format('RELEASE SAVEPOINT %I', v_savepoint_name);
        RETURN v_result;
    EXCEPTION WHEN OTHERS THEN
        EXECUTE format('ROLLBACK TO SAVEPOINT %I', v_savepoint_name);
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Transaction timeout enforcer
CREATE OR REPLACE FUNCTION begin_timed_transaction(
    p_timeout_ms INT DEFAULT 30000
) RETURNS VOID AS $$
BEGIN
    SET LOCAL statement_timeout = p_timeout_ms || 'ms';
    SET LOCAL idle_in_transaction_session_timeout = p_timeout_ms || 'ms';
END;
$$ LANGUAGE plpgsql;

-- Saga pattern support
CREATE TABLE IF NOT EXISTS saga_log (
    saga_id UUID PRIMARY KEY,
    saga_name TEXT NOT NULL,
    current_step INT DEFAULT 0,
    total_steps INT NOT NULL,
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'compensating', 'compensated', 'failed')),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    context JSONB DEFAULT '{}'
);

-- Start saga
CREATE OR REPLACE FUNCTION saga_start(
    p_saga_id UUID,
    p_saga_name TEXT,
    p_total_steps INT,
    p_context JSONB DEFAULT '{}'
) RETURNS VOID AS $$
BEGIN
    INSERT INTO saga_log (saga_id, saga_name, total_steps, status, context)
    VALUES (p_saga_id, p_saga_name, p_total_steps, 'pending', p_context)
    ON CONFLICT (saga_id) DO UPDATE SET
        current_step = 0, status = 'running', context = p_context;
END;
$$ LANGUAGE plpgsql;

-- Complete saga step
CREATE OR REPLACE FUNCTION saga_step_complete(
    p_saga_id UUID,
    p_step INT
) RETURNS VOID AS $$
BEGIN
    UPDATE saga_log SET current_step = p_step
    WHERE saga_id = p_saga_id AND status = 'running';
END;
$$ LANGUAGE plpgsql;

-- Compensate saga
CREATE OR REPLACE FUNCTION saga_compensate(
    p_saga_id UUID,
    p_error_message TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE saga_log SET 
        status = 'compensating',
        context = context || jsonb_build_object('error', p_error_message)
    WHERE saga_id = p_saga_id;
END;
$$ LANGUAGE plpgsql;