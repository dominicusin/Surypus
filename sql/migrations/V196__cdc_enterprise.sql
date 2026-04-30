-- ============================================================================
-- Enterprise CDC: Change Data Capture Advanced
-- ============================================================================

-- CDC configuration
CREATE TABLE IF NOT EXISTS cdc_configs (
    id SERIAL PRIMARY KEY,
    table_name TEXT UNIQUE NOT NULL,
    capture_inserts BOOLEAN DEFAULT TRUE,
    capture_updates BOOLEAN DEFAULT TRUE,
    capture_deletes BOOLEAN DEFAULT TRUE,
    include_before_state BOOLEAN DEFAULT TRUE,
    include_after_state BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Enable CDC for key tables
INSERT INTO cdc_configs (table_name, capture_inserts, capture_updates, capture_deletes)
VALUES 
    ('event_store', TRUE, FALSE, FALSE),
    ('aggregates', TRUE, TRUE, TRUE),
    ('users', TRUE, TRUE, TRUE),
    ('tenant_users', TRUE, TRUE, TRUE)
ON CONFLICT (table_name) DO NOTHING;

-- CDC audit trail
CREATE TABLE IF NOT EXISTS cdc_audit (
    id BIGSERIAL PRIMARY KEY,
    cdc_id BIGINT REFERENCES cdc_log(id),
    processed_at TIMESTAMPTZ DEFAULT NOW(),
    destination_system TEXT,
    destination_topic TEXT,
    status TEXT CHECK (status IN ('pending', 'processed', 'failed'))
);

-- Transform CDC data
CREATE OR REPLACE FUNCTION cdc_transform(
    p_cdc_id BIGINT,
    p_format TEXT DEFAULT 'json'
) RETURNS JSONB AS $$
DECLARE
    v_cdc RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_cdc FROM cdc_log WHERE id = p_cdc_id;
    
    v_result := jsonb_build_object(
        'operation', v_cdc.operation,
        'timestamp', v_cdc.timestamp,
        'table', v_cdc.table_name,
        'before', CASE WHEN v_cdc.include_before_state THEN v_cdc.old_data END,
        'after', CASE WHEN v_cdc.include_after_state THEN v_cdc.new_data END,
        'primary_key', v_cdc.primary_key
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;