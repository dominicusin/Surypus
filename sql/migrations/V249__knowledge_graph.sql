-- ============================================================================
-- Advanced Knowledge Graph
-- ============================================================================
-- Depends on the optional pgvector extension. Guard the whole migration so it is a
-- no-op where pgvector is unavailable and applies fully where present.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
        EXECUTE 'CREATE EXTENSION IF NOT EXISTS vector';

        EXECUTE 'CREATE TABLE IF NOT EXISTS kg_entities (
            id SERIAL PRIMARY KEY,
            entity_id UUID DEFAULT gen_random_uuid(),
            entity_type TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            embeddings VECTOR(1536),
            metadata JSONB DEFAULT ''{}'',
            confidence_score FLOAT DEFAULT 1.0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(entity_type, name)
        )';

        EXECUTE 'CREATE TABLE IF NOT EXISTS kg_relationships (
            id SERIAL PRIMARY KEY,
            from_entity_id UUID REFERENCES kg_entities(entity_id),
            to_entity_id UUID REFERENCES kg_entities(entity_id),
            relationship_type TEXT NOT NULL,
            weight FLOAT DEFAULT 1.0,
            evidence JSONB DEFAULT ''{}'',
            created_at TIMESTAMPTZ DEFAULT NOW()
        )';

        EXECUTE 'CREATE OR REPLACE FUNCTION kg_add_entity(
            p_entity_type TEXT, p_name TEXT, p_description TEXT DEFAULT NULL, p_metadata JSONB DEFAULT ''{}''
        ) RETURNS UUID AS $f$
        DECLARE v_entity_id UUID;
        BEGIN
            INSERT INTO kg_entities (entity_type, name, description, metadata)
            VALUES (p_entity_type, p_name, p_description, p_metadata)
            RETURNING entity_id INTO v_entity_id;
            RETURN v_entity_id;
        END;
        $f$ LANGUAGE plpgsql';

        EXECUTE 'CREATE OR REPLACE FUNCTION kg_relate(
            p_from_type TEXT, p_from_name TEXT, p_to_type TEXT, p_to_name TEXT, p_relationship_type TEXT
        ) RETURNS VOID AS $f$
        DECLARE v_from_id UUID; v_to_id UUID;
        BEGIN
            SELECT entity_id INTO v_from_id FROM kg_entities WHERE entity_type = p_from_type AND name = p_from_name;
            SELECT entity_id INTO v_to_id FROM kg_entities WHERE entity_type = p_to_type AND name = p_to_name;
            INSERT INTO kg_relationships (from_entity_id, to_entity_id, relationship_type)
            VALUES (v_from_id, v_to_id, p_relationship_type)
            ON CONFLICT DO NOTHING;
        END;
        $f$ LANGUAGE plpgsql';
    END IF;
END $$;
