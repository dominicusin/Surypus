-- ============================================================================
-- Query Whitelist: Enterprise Edition
-- ============================================================================

-- Query categories
CREATE TABLE IF NOT EXISTS query_categories (
    id SERIAL PRIMARY KEY,
    category_name TEXT UNIQUE NOT NULL,
    description TEXT,
    risk_level INT CHECK (risk_level BETWEEN 1 AND 5),
    is_dangerous BOOLEAN GENERATED ALWAYS AS (risk_level >= 4) STORED
);

-- Whitelist with categories
ALTER TABLE query_whitelist ADD COLUMN IF NOT EXISTS category_id INT REFERENCES query_categories(id);
ALTER TABLE query_whitelist ADD COLUMN IF NOT EXISTS requires_audit BOOLEAN DEFAULT FALSE;

-- Default categories
INSERT INTO query_categories (category_name, description, risk_level)
VALUES 
    ('read_only', 'SELECT queries', 1),
    ('insert_only', 'INSERT operations', 2),
    ('update_own', 'UPDATE self-owned records', 2),
    ('delete_own', 'DELETE self-owned records', 3),
    ('admin', 'Administrative operations', 4),
    ('ddl', 'Schema modifications', 5)
ON CONFLICT (category_name) DO NOTHING;

-- Update existing whitelist
UPDATE query_whitelist qw
SET category_id = (
    SELECT id FROM query_categories 
    WHERE CASE 
        WHEN qw.query_template ILIKE 'SELECT%' THEN 'read_only'
        WHEN qw.query_template ILIKE 'INSERT%' THEN 'insert_only'
        WHEN qw.query_template ILIKE 'UPDATE%' THEN 'update_own'
        WHEN qw.query_template ILIKE 'DELETE%' THEN 'delete_own'
        WHEN qw.query_template ILIKE 'ALTER%' OR qw.query_template ILIKE 'DROP%' THEN 'ddl'
        ELSE 'admin'
    END = category_name
)
WHERE category_id IS NULL;

-- Query audit trail
CREATE TABLE IF NOT EXISTS query_audit_trail (
    id BIGSERIAL PRIMARY KEY,
    query_hash TEXT NOT NULL,
    query_template TEXT,
    user_id UUID,
    ip_address INET,
    execution_time_ms INT,
    result_rows INT,
    status TEXT CHECK (status IN ('allowed', 'blocked', 'error')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_query_audit_date ON query_audit_trail(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_query_audit_hash ON query_audit_trail(query_hash);

-- Enforce whitelist
CREATE OR REPLACE FUNCTION enforce_whitelist(
    p_query TEXT,
    p_user_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_allowed BOOLEAN;
    v_template TEXT;
    v_hash TEXT;
    v_audit_id BIGINT;
BEGIN
    v_template := extract_query_template(p_query);
    v_hash := md5(v_template);
    
    -- Check whitelist
    SELECT is_enabled INTO v_allowed
    FROM query_whitelist
    WHERE query_template = v_template OR query_hash = v_hash;
    
    -- Track
    INSERT INTO query_audit_trail (query_hash, query_template, user_id, status)
    VALUES (v_hash, v_template, p_user_id, CASE WHEN v_allowed THEN 'allowed' ELSE 'blocked' END);
    
    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Query not in whitelist: %', v_template;
    END IF;
    
    RETURN v_allowed;
END;
$$ LANGUAGE plpgsql;

-- Get blocked queries
CREATE OR REPLACE FUNCTION get_blocked_queries(p_hours INT DEFAULT 24)
RETURNS TABLE(query_template TEXT, block_count INT, last_attempt TIMESTAMP WITH TIME ZONE) AS $$
BEGIN
    RETURN QUERY
    SELECT qat.query_template, COUNT(*)::INT, MAX(qat.created_at)
    FROM query_audit_trail qat
    WHERE qat.status = 'blocked'
      AND qat.created_at > NOW() - (p_hours || ' hours')::INTERVAL
    GROUP BY qat.query_template;
END;
$$ LANGUAGE plpgsql;