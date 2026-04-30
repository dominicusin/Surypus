-- ============================================================================
-- Query Whitelist
-- ============================================================================

-- Query whitelist table
CREATE TABLE IF NOT EXISTS query_whitelist (
    id SERIAL PRIMARY KEY,
    query_hash TEXT UNIQUE NOT NULL,
    query_template TEXT NOT NULL,
    description TEXT,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Default allowed patterns
INSERT INTO query_whitelist (query_template, description, is_enabled)
VALUES 
    ('SELECT * FROM event_store WHERE aggregate_id = %', 'Event store by aggregate', TRUE),
    ('SELECT * FROM event_store WHERE tenant_id = %', 'Event store by tenant', TRUE),
    ('SELECT * FROM aggregates WHERE tenant_id = %', 'Aggregates by tenant', TRUE),
    ('SELECT COUNT(*) FROM %', 'Count queries', TRUE),
    ('INSERT INTO event_store%', 'Event append', TRUE),
    ('UPDATE aggregates SET%', 'Aggregate update', TRUE)
ON CONFLICT (query_template) DO NOTHING;

-- Validate query against whitelist
CREATE OR REPLACE FUNCTION validate_query_allowed(
    p_query TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_allowed BOOLEAN := FALSE;
    v_pattern TEXT;
    v_hash TEXT;
BEGIN
    -- Generate hash
    v_hash := md5(p_query)::TEXT;
    
    -- Check whitelist
    SELECT EXISTS (
        SELECT 1 FROM query_whitelist
        WHERE is_enabled = TRUE
          AND p_query ILIKE query_template
    ) INTO v_allowed;
    
    -- Log check
    IF NOT v_allowed THEN
        RAISE NOTICE 'Query not in whitelist: %', substring(p_query, 1, 100);
    END IF;
    
    RETURN v_allowed;
END;
$$ LANGUAGE plpgsql;

-- Query template extractor
CREATE OR REPLACE FUNCTION extract_query_template(
    p_query TEXT
) RETURNS TEXT AS $$
DECLARE
    v_template TEXT;
BEGIN
    v_template := p_query;
    
    -- Normalize literals
    v_template := regexp_replace(v_template, '''[^'']+''', '''%''', 'g');
    v_template := regexp_replace(v_template, '[0-9]+', '%', 'g');
    v_template := regexp_replace(v_template, '[a-f0-9-]{36}', '%', 'gi');
    
    RETURN v_template;
END;
$$ LANGUAGE plpgsql;

-- Add to whitelist
CREATE OR REPLACE FUNCTION whitelist_add(
    p_query TEXT,
    p_description TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_template TEXT;
    v_hash TEXT;
BEGIN
    v_template := extract_query_template(p_query);
    v_hash := md5(v_template);
    
    INSERT INTO query_whitelist (query_hash, query_template, description)
    VALUES (v_hash, v_template, p_description)
    ON CONFLICT (query_hash) DO UPDATE SET
        description = COALESCE(p_description, query_whitelist.description);
END;
$$ LANGUAGE plpgsql;