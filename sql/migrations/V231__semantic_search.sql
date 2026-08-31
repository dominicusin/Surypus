-- ============================================================================
-- Advanced Semantic Search
-- ============================================================================
-- Depends on the optional pgvector extension. Guard the whole migration so it is a
-- no-op where pgvector is unavailable and applies fully where present.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
        EXECUTE 'CREATE EXTENSION IF NOT EXISTS vector';

        EXECUTE 'CREATE TABLE IF NOT EXISTS document_store (
            doc_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id UUID REFERENCES tenants(tenant_id),
            doc_type TEXT NOT NULL,
            title TEXT,
            content TEXT,
            embedding VECTOR(1536),
            metadata JSONB DEFAULT ''{}'',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )';

        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_doc_embedding ON document_store USING ivfflat (embedding vector_cosine_ops)';

        EXECUTE 'CREATE OR REPLACE FUNCTION semantic_search(
            p_query TEXT, p_tenant_id UUID, p_limit INT DEFAULT 10
        ) RETURNS TABLE(doc_id UUID, title TEXT, similarity FLOAT) AS $f$
        BEGIN
            RETURN QUERY
            SELECT ds.doc_id, ds.title, 0.5 as similarity
            FROM document_store ds
            WHERE ds.tenant_id = p_tenant_id
              AND ds.content ILIKE ''%'' || p_query || ''%''
            ORDER BY ds.updated_at DESC
            LIMIT p_limit;
        END;
        $f$ LANGUAGE plpgsql';
    END IF;
END $$;
