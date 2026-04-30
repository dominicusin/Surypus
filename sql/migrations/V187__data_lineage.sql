-- ============================================================================
-- Data Lineage Tracking
-- ============================================================================

-- Data lineage table
CREATE TABLE IF NOT EXISTS data_lineage (
    id BIGSERIAL PRIMARY KEY,
    source_system TEXT,
    source_table TEXT,
    source_id TEXT,
    target_system TEXT,
    target_table TEXT,
    target_id TEXT,
    transformation_type TEXT,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lineage_source ON data_lineage(source_system, source_table, source_id);
CREATE INDEX IF NOT EXISTS idx_lineage_target ON data_lineage(target_system, target_table, target_id);

-- Record lineage
CREATE OR REPLACE FUNCTION record_lineage(
    p_source_system TEXT,
    p_source_table TEXT,
    p_source_id TEXT,
    p_target_system TEXT,
    p_target_table TEXT,
    p_target_id TEXT,
    p_transformation_type TEXT DEFAULT 'copy'
) RETURNS VOID AS $$
BEGIN
    INSERT INTO data_lineage (
        source_system, source_table, source_id,
        target_system, target_table, target_id,
        transformation_type
    ) VALUES (
        p_source_system, p_source_table, p_source_id,
        p_target_system, p_target_table, p_target_id,
        p_transformation_type
    );
END;
$$ LANGUAGE plpgsql;

-- Get data ancestry
CREATE OR REPLACE FUNCTION get_data_ancestry(
    p_table_name TEXT,
    p_record_id TEXT,
    p_depth INT DEFAULT 10
) RETURNS TABLE(
    lineage_level INT,
    source_system TEXT,
    source_table TEXT,
    source_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE ancestry AS (
        SELECT 0 as level, dl.*
        FROM data_lineage dl
        WHERE dl.target_table = p_table_name AND dl.target_id = p_record_id
        
        UNION ALL
        
        SELECT a.level + 1, dl.*
        FROM ancestry a
        JOIN data_lineage dl ON 
            dl.target_table = a.source_table AND dl.target_id = a.source_id
        WHERE a.level < p_depth
    )
    SELECT ancestry.level, ancestry.source_system, ancestry.source_table, 
           ancestry.source_id, ancestry.created_at
    FROM ancestry;
END;
$$ LANGUAGE plpgsql;