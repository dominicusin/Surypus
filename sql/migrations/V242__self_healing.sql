-- ============================================================================
-- Advanced Self-Healing Database
-- ============================================================================

-- Healing rules
CREATE TABLE IF NOT EXISTS healing_rules (
    id SERIAL PRIMARY KEY,
    condition_type TEXT NOT NULL,
    condition_pattern TEXT NOT NULL,
    action_type TEXT NOT NULL,
    action_definition JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered TIMESTAMPTZ
);

-- Register healing rules
INSERT INTO healing_rules (condition_type, condition_pattern, action_type, action_definition)
VALUES 
    ('query_timeout', '> 30000', 'index_recommend', '{"action": "CREATE INDEX"}'::JSONB),
    ('connection_saturation', '> 80%', 'connection_cleanup', '{"action": "kill_idle_connections"}'::JSONB)
ON CONFLICT DO NOTHING;

-- Auto-healing execution
CREATE OR REPLACE FUNCTION execute_healing(
    p_condition_type TEXT,
    p_condition_value TEXT
) RETURNS VOID AS $$
DECLARE
    v_rule RECORD;
BEGIN
    SELECT * INTO v_rule FROM healing_rules 
    WHERE condition_type = p_condition_type AND is_active = TRUE;
    
    IF v_rule IS NULL THEN
        RETURN;
    END IF;
    
    CASE v_rule.action_type
        WHEN 'index_recommend' THEN
            RAISE NOTICE 'Healing: Index recommendation triggered for %', p_condition_value;
        WHEN 'connection_cleanup' THEN
            PERFORM admin_kill_idle_connections(300);
        ELSE
            NULL;
    END CASE;
    
    UPDATE healing_rules SET last_triggered = NOW() WHERE id = v_rule.id;
END;
$$ LANGUAGE plpgsql;

-- Health score calculation
CREATE OR REPLACE FUNCTION calculate_health_score() RETURNS JSONB AS $$
DECLARE
    v_score NUMERIC := 100;
    v_issues JSONB := '[]'::JSONB;
BEGIN
    -- Check connection pool
    IF (SELECT COUNT(*) FROM pg_stat_activity) > 80 THEN
        v_score := v_score - 10;
        v_issues := v_issues || '"high_connection_usage"'::JSONB;
    END IF;
    
    -- Check DLQ
    IF (SELECT COUNT(*) FROM event_dlq WHERE resolved = FALSE) > 100 THEN
        v_score := v_score - 15;
        v_issues := v_issues || '"high_dlq_backlog"'::JSONB;
    END IF;
    
    RETURN jsonb_build_object(
        'health_score', GREATEST(0, v_score),
        'issues', v_issues,
        'timestamp', NOW()
    );
END;
$$ LANGUAGE plpgsql;