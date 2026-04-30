-- Enhanced error context logging
CREATE TABLE IF NOT EXISTS error_context_log (
    log_id BIGSERIAL PRIMARY KEY,
    error_code TEXT,
    context JSONB,
    stack_trace TEXT,
    user_id UUID,
    tenant_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Function to log error context
CREATE OR REPLACE FUNCTION log_error_context(
    p_error_code TEXT,
    p_context JSONB,
    p_stack_trace TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_log_id BIGINT;
BEGIN
    INSERT INTO error_context_log (error_code, context, stack_trace, user_id, tenant_id, created_at)
    VALUES (p_error_code, p_context, p_stack_trace, p_user_id, p_tenant_id, CURRENT_TIMESTAMP)
    RETURNING log_id INTO v_log_id;
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Error aggregation view
CREATE OR REPLACE VIEW v_error_summary AS
SELECT 
    error_code,
    COUNT(*) as occurrence_count,
    COUNT(DISTINCT tenant_id) as affected_tenants,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence
FROM error_context_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY error_code;