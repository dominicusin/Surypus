-- Data retention policies
CREATE TABLE IF NOT EXISTS data_retention_policies (
    policy_id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT,
    retention_period INTERVAL NOT NULL,
    action TEXT CHECK (action IN ('archive', 'delete', 'anonymize')),
    enabled BOOLEAN DEFAULT TRUE,
    UNIQUE(table_name, column_name)
);

-- Default retention: 7 years for events
INSERT INTO data_retention_policies (table_name, column_name, retention_period, action, enabled)
VALUES 
    ('event_store', 'created_at', INTERVAL '7 years', 'archive', TRUE),
    ('projection_audit', 'created_at', INTERVAL '1 year', 'delete', TRUE),
    ('api_keys_audit', 'created_at', INTERVAL '2 years', 'archive', TRUE)
ON CONFLICT (table_name, column_name) DO NOTHING;

-- Apply retention policy
CREATE OR REPLACE FUNCTION apply_retention_policy(
    p_table_name TEXT,
    p_column_name TEXT,
    p_retention_period INTERVAL
) RETURNS INT AS $$
DECLARE
    v_deleted INT;
    v_sql TEXT;
BEGIN
    v_sql := format('DELETE FROM %I WHERE %I < NOW() - %L', 
        p_table_name, p_column_name, p_retention_period);
    EXECUTE v_sql;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- Anonymize user data
CREATE OR REPLACE FUNCTION anonymize_user(p_user_id UUID) RETURNS VOID AS $$
BEGIN
    UPDATE users SET 
        email = 'redacted_' || user_id || '@redacted.com',
        password_hash = 'REDACTED'
    WHERE user_id = p_user_id;
    
    UPDATE tenant_users SET roles = '{}'
    WHERE user_id = p_user_id;
    
    RAISE NOTICE 'User % anonymized', p_user_id;
END;
$$ LANGUAGE plpgsql;