-- ============================================================================
-- Advanced Event Processing (Complex Event Processing)
-- ============================================================================

-- Event patterns
CREATE TABLE IF NOT EXISTS event_patterns (
    id SERIAL PRIMARY KEY,
    pattern_name TEXT UNIQUE NOT NULL,
    pattern_definition JSONB NOT NULL,  -- {events: [{type: 'A'}, {type: 'B', within: 60}], action: 'notify'}
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pattern match log
CREATE TABLE IF NOT EXISTS pattern_matches (
    id BIGSERIAL PRIMARY KEY,
    pattern_id INT REFERENCES event_patterns(id),
    matched_events JSONB NOT NULL,
    triggered_at TIMESTAMPTZ DEFAULT NOW(),
    action_taken JSONB
);

-- Register patterns
INSERT INTO event_patterns (pattern_name, pattern_definition)
VALUES 
    ('rapid_events', '{"events": [{"type": "StockIssued"}, {"type": "StockIssued"}, {"type": "StockIssued"}], "within": 60, "action": "alert"}'::JSONB),
    ('threshold_exceeded', '{"events": [{"type": "StockAdjusted", "condition": "qty > 100"}], "action": "notify"}'::JSONB)
ON CONFLICT (pattern_name) DO NOTHING;

-- Process event for patterns
CREATE OR REPLACE FUNCTION process_event_patterns(
    p_event_type TEXT,
    p_event_data JSONB,
    p_tenant_id UUID
) RETURNS VOID AS $$
DECLARE
    v_pattern RECORD;
    v_matches INT;
BEGIN
    FOR v_pattern IN SELECT * FROM event_patterns WHERE is_active = TRUE
    LOOP
        -- Simplified pattern matching
        IF v_pattern.pattern_definition->'events'->0->>'type' = p_event_type THEN
            v_matches := v_matches + 1;
            
            INSERT INTO pattern_matches (pattern_id, matched_events, action_taken)
            VALUES (v_pattern.id, jsonb_build_array(p_event_data), v_pattern.pattern_definition->'action');
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;