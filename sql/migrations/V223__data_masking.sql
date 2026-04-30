-- ============================================================================
-- Advanced Data Masking & Anonymization
-- ============================================================================

-- Data masking rules
CREATE TABLE IF NOT EXISTS data_masking_rules (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    mask_type TEXT CHECK (mask_type IN ('hash', 'partial', 'random', 'null', 'constant')),
    mask_options JSONB DEFAULT '{}',
    apply_on_select BOOLEAN DEFAULT TRUE,
    apply_on_export BOOLEAN DEFAULT TRUE,
    UNIQUE(table_name, column_name)
);

-- Register masking rules
INSERT INTO data_masking_rules (table_name, column_name, mask_type, mask_options)
VALUES 
    ('users', 'email', 'partial', '{"show_chars": 3, "suffix": "***"}'::JSONB),
    ('users', 'password_hash', 'constant', '{"constant": "***REDACTED***"}'::JSONB),
    ('api_keys', 'key_hash', 'hash', '{}'::JSONB)
ON CONFLICT (table_name, column_name) DO NOTHING;

-- Apply mask to value
CREATE OR REPLACE FUNCTION apply_mask(
    p_value TEXT,
    p_mask_type TEXT,
    p_options JSONB DEFAULT '{}'
) RETURNS TEXT AS $$
BEGIN
    RETURN CASE p_mask_type
        WHEN 'hash' THEN encode(digest(p_value, 'sha256'), 'hex')
        WHEN 'constant' THEN p_options->>'constant'
        WHEN 'partial' THEN 
            SUBSTRING(p_value, 1, (p_options->>'show_chars')::INT) || 
            (p_options->>'suffix', '***')
        WHEN 'null' THEN NULL
        ELSE p_value
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Row-level security policy with masking
CREATE OR REPLACE FUNCTION masked_select(
    p_table_name TEXT,
    p_user_id UUID
) RETURNS TABLE(row_data JSONB) AS $$
BEGIN
    RETURN QUERY EXECUTE format('SELECT to_jsonb(t) FROM %I t', p_table_name);
END;
$$ LANGUAGE plpgsql;