-- ============================================================================
-- Enterprise Complete: Time Travel, Lineage, and Advanced Features
-- ============================================================================

-- Enhanced lineage with transformation tracking
ALTER TABLE data_lineage ADD COLUMN IF NOT EXISTS transformation_logic TEXT;
ALTER TABLE data_lineage ADD COLUMN IF NOT EXISTS batch_id UUID;
ALTER TABLE data_lineage ADD COLUMN IF NOT EXISTS correlation_id UUID;

-- Track data transformation
CREATE OR REPLACE FUNCTION track_transformation(
    p_source_table TEXT,
    p_source_id TEXT,
    p_target_table TEXT,
    p_target_id TEXT,
    p_transformation_logic TEXT,
    p_batch_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    PERFORM record_lineage(
        'internal', p_source_table, p_source_id,
        'internal', p_target_table, p_target_id,
        p_transformation_logic
    );
    
    UPDATE data_lineage SET 
        transformation_logic = p_transformation_logic,
        batch_id = p_batch_id
    WHERE source_table = p_source_table AND source_id = p_source_id
      AND target_table = p_target_table AND target_id = p_target_id;
END;
$$ LANGUAGE plpgsql;

-- Time travel with full audit
CREATE OR REPLACE FUNCTION temporal_query(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_at TIMESTAMPTZ,
    p_include_system_time BOOLEAN DEFAULT TRUE
) RETURNS TABLE(
    state_data JSONB,
    loaded_at TIMESTAMPTZ,
    version INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ts.state_data,
        ts.valid_from,
        ROW_NUMBER() OVER (ORDER BY ts.valid_from DESC)::INT as version
    FROM temporal_snapshots ts
    WHERE ts.entity_type = p_entity_type 
      AND ts.entity_id = p_entity_id
      AND p_at >= ts.valid_from
      AND (ts.valid_to IS NULL OR p_at < ts.valid_to)
    ORDER BY ts.valid_from DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Audit snapshot for compliance
CREATE OR REPLACE FUNCTION audit_snapshot(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_at TIMESTAMPTZ
) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Get state at point in time
    SELECT state_data INTO v_result
    FROM temporal_snapshots
    WHERE entity_type = p_entity_type AND entity_id = p_entity_id
      AND p_at >= valid_from AND (valid_to IS NULL OR p_at < valid_to)
    ORDER BY valid_from DESC LIMIT 1;
    
    -- Get audit trail
    RETURN jsonb_build_object(
        'state', v_result,
        'audit', (SELECT jsonb_agg(jsonb_build_object(
            'action', action,
            'user', user_id,
            'timestamp', created_at,
            'changes', changes
        )) FROM audit_trail 
         WHERE entity_type = p_entity_type AND entity_id = p_entity_id AND created_at <= p_at)
    );
END;
$$ LANGUAGE plpgsql;

-- Graph lineage (for data flow visualization)
CREATE OR REPLACE FUNCTION get_lineage_graph(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_depth INT DEFAULT 5
) RETURNS TABLE(
    node_type TEXT,
    node_id TEXT,
    node_label TEXT,
    relationship TEXT,
    depth INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE lineage_graph AS (
        SELECT 
            'source' as node_type,
            source_id as node_id,
            source_table as node_label,
            'originates' as relationship,
            0 as depth
        FROM data_lineage
        WHERE target_table = p_entity_type AND target_id = p_entity_id
        
        UNION ALL
        
        SELECT 
            CASE WHEN dl.target_table = p_entity_type THEN 'source' ELSE 'intermediate' END,
            dl.source_id,
            dl.source_table,
            'derived_from',
            lg.depth + 1
        FROM lineage_graph lg
        JOIN data_lineage dl ON dl.target_table = lg.node_id AND dl.target_table = lg.node_label
        WHERE lg.depth < p_depth
    )
    SELECT node_type, node_id, node_label, relationship, depth FROM lineage_graph;
END;
$$ LANGUAGE plpgsql;