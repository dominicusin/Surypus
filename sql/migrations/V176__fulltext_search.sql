-- ============================================================================
-- Full-Text Search Support
-- ============================================================================

-- Search index table
CREATE TABLE IF NOT EXISTS search_index (
    id BIGSERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    title TEXT,
    content TSVECTOR,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(entity_type, entity_id)
);

-- GIN index for full-text search
CREATE INDEX IF NOT EXISTS idx_search_content ON search_index USING GIN(content);
CREATE INDEX IF NOT EXISTS idx_search_tenant ON search_index(tenant_id);

-- Index content
CREATE OR REPLACE FUNCTION index_content(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_tenant_id UUID,
    p_title TEXT,
    p_content TEXT,
    p_metadata JSONB DEFAULT '{}'
) RETURNS VOID AS $$
BEGIN
    INSERT INTO search_index (entity_type, entity_id, tenant_id, title, content, metadata)
    VALUES (
        p_entity_type, p_entity_id, p_tenant_id, p_title,
        to_tsvector('english', COALESCE(p_title || ' ', '') || COALESCE(p_content, '')),
        p_metadata
    )
    ON CONFLICT (entity_type, entity_id) DO UPDATE SET
        title = EXCLUDED.title,
        content = EXCLUDED.content,
        metadata = EXCLUDED.metadata,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Search function
CREATE OR REPLACE FUNCTION search_entities(
    p_tenant_id UUID,
    p_query TEXT,
    p_entity_type TEXT DEFAULT NULL,
    p_limit INT DEFAULT 50
) RETURNS TABLE(entity_type TEXT, entity_id UUID, title TEXT, rank NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        si.entity_type,
        si.entity_id,
        si.title,
        ts_rank(si.content, plainto_tsquery('english', p_query)) as rank
    FROM search_index si
    WHERE si.tenant_id = p_tenant_id
      AND si.content @@ plainto_tsquery('english', p_query)
      AND (p_entity_type IS NULL OR si.entity_type = p_entity_type)
    ORDER BY rank DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;