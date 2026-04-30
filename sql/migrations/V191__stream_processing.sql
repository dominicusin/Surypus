-- ============================================================================
-- Stream Processing Support
-- ============================================================================

-- Stream definitions
CREATE TABLE IF NOT EXISTS streams (
    stream_id SERIAL PRIMARY KEY,
    stream_name TEXT UNIQUE NOT NULL,
    source_table TEXT NOT NULL,
    partition_key TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default streams
INSERT INTO streams (stream_name, source_table, partition_key)
VALUES 
    ('events_stream', 'event_store', 'tenant_id'),
    ('projection_stream', 'projection_audit', 'projection_name'),
    ('audit_stream', 'audit_trail', 'tenant_id')
ON CONFLICT (stream_name) DO NOTHING;

-- Stream processor state
CREATE TABLE IF NOT EXISTS stream_processor_state (
    processor_id TEXT PRIMARY KEY,
    stream_name TEXT NOT NULL,
    last_offset BIGINT,
    last_timestamp TIMESTAMPTZ,
    status TEXT CHECK (status IN ('idle', 'processing', 'error')),
    error_message TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Process stream window
CREATE OR REPLACE FUNCTION process_stream_window(
    p_processor_id TEXT,
    p_stream_name TEXT,
    p_window_seconds INT DEFAULT 60
) RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_state RECORD;
BEGIN
    -- Get processor state
    SELECT * INTO v_state FROM stream_processor_state WHERE processor_id = p_processor_id;
    
    IF v_state IS NULL THEN
        INSERT INTO stream_processor_state (processor_id, stream_name, status)
        VALUES (p_processor_id, p_stream_name, 'processing')
        ON CONFLICT (processor_id) DO NOTHING;
    ELSE
        UPDATE stream_processor_state SET status = 'processing', updated_at = NOW()
        WHERE processor_id = p_processor_id;
    END IF;
    
    -- Simulate processing
    v_count := (SELECT COUNT(*) FROM event_store WHERE created_at > NOW() - (p_window_seconds || ' seconds')::INTERVAL);
    
    -- Update state
    UPDATE stream_processor_state 
    SET last_offset = v_count, status = 'idle', last_timestamp = NOW()
    WHERE processor_id = p_processor_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;