-- ============================================================================
-- Time Travel Queries
-- ============================================================================

-- Temporal table support
CREATE TABLE IF NOT EXISTS temporal_snapshots (
    id BIGSERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_to TIMESTAMP WITH TIME ZONE,
    state_data JSONB NOT NULL,
    is_current BOOLEAN GENERATED ALWAYS AS (valid_to IS NULL) STORED,
    UNIQUE(entity_type, entity_id, valid_from)
);

-- Record temporal state
CREATE OR REPLACE FUNCTION record_temporal_state(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_state_data JSONB
) RETURNS VOID AS $$
BEGIN
    -- Close current
    UPDATE temporal_snapshots 
    SET valid_to = NOW()
    WHERE entity_type = p_entity_type 
      AND entity_id = p_entity_id 
      AND valid_to IS NULL;
    
    -- Insert new
    INSERT INTO temporal_snapshots (entity_type, entity_id, valid_from, state_data)
    VALUES (p_entity_type, p_entity_id, NOW(), p_state_data);
END;
$$ LANGUAGE plpgsql;

-- Temporal point-in-time query
CREATE OR REPLACE FUNCTION point_in_time(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_at TIMESTAMP WITH TIME ZONE
) RETURNS JSONB AS $$
DECLARE
    v_state JSONB;
BEGIN
    SELECT state_data INTO v_state
    FROM temporal_snapshots
    WHERE entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND p_at >= valid_from
      AND (valid_to IS NULL OR p_at < valid_to)
    ORDER BY valid_from DESC
    LIMIT 1;
    
    RETURN v_state;
END;
$$ LANGUAGE plpgsql;

-- Get all versions
CREATE OR REPLACE FUNCTION get_versions(
    p_entity_type TEXT,
    p_entity_id TEXT
) RETURNS TABLE(valid_from TIMESTAMP, valid_to TIMESTAMP, state_data JSONB) AS $$
BEGIN
    RETURN QUERY
    SELECT ts.valid_from, ts.valid_to, ts.state_data
    FROM temporal_snapshots ts
    WHERE ts.entity_type = p_entity_type AND ts.entity_id = p_entity_id
    ORDER BY ts.valid_from DESC;
END;
$$ LANGUAGE plpgsql;