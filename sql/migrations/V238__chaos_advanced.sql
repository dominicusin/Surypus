-- ============================================================================
-- Advanced Chaos Engineering & Fault Injection
-- ============================================================================

-- Fault injection rules
CREATE TABLE IF NOT EXISTS fault_injection_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    target_operation TEXT NOT NULL,
    fault_type TEXT CHECK (fault_type IN ('delay', 'error', 'drop', 'corrupt')),
    fault_parameters JSONB DEFAULT '{}',
    probability FLOAT CHECK (probability BETWEEN 0 AND 1),
    is_active BOOLEAN DEFAULT FALSE
);

-- Register fault rules
INSERT INTO fault_injection_rules (rule_name, target_operation, fault_type, fault_parameters, probability)
VALUES 
    ('random_delay', 'query_execution', 'delay', '{"min_ms": 100, "max_ms": 500}', 0.1),
    ('random_error', 'event_append', 'error', '{"error_code": "ERR_SIMULATED"}', 0.05)
ON CONFLICT (rule_name) DO NOTHING;

-- Apply fault injection
CREATE OR REPLACE FUNCTION maybe_inject_fault(
    p_operation TEXT
) RETURNS VOID AS $$
DECLARE
    v_rule RECORD;
    v_roll FLOAT;
BEGIN
    SELECT * INTO v_rule FROM fault_injection_rules 
    WHERE target_operation = p_operation AND is_active = TRUE;
    
    IF v_rule IS NULL THEN
        RETURN;
    END IF;
    
    v_roll := random();
    
    IF v_roll <= v_rule.probability THEN
        CASE v_rule.fault_type
            WHEN 'delay' THEN
                PERFORM pg_sleep((v_rule.fault_parameters->>'max_ms')::INT / 1000.0);
            WHEN 'error' THEN
                RAISE EXCEPTION 'Injected fault: %', v_rule.fault_parameters->>'error_code';
            WHEN 'drop' THEN
                RETURN;  -- Silently skip
            ELSE
                NULL;
        END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Chaos experiment execution
CREATE TABLE IF NOT EXISTS chaos_executions (
    id BIGSERIAL PRIMARY KEY,
    experiment_id INT REFERENCES chaos_experiments(id),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    affected_operations INT DEFAULT 0,
    success_rate FLOAT
);