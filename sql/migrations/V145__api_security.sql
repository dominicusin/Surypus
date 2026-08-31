-- API key validation table (enhanced)
-- Ensure the referenced api_keys table exists (it may be created by a later
-- domain migration); provide a minimal schema so the FK/function below resolve.
CREATE TABLE IF NOT EXISTS api_keys (
    key_id UUID PRIMARY KEY,
    user_id UUID,
    key_hash TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS api_keys_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    key_id UUID REFERENCES api_keys(key_id),
    user_id UUID,
    action TEXT,
    success BOOLEAN,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Validate API key with audit
CREATE OR REPLACE FUNCTION validate_api_key(
    p_key_hash TEXT,
    p_action TEXT,
    p_ip_address INET DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_key_record RECORD;
    v_user_id UUID;
    v_success BOOLEAN := FALSE;
BEGIN
    SELECT key_id, user_id, is_active INTO v_key_record
    FROM api_keys
    WHERE key_hash = p_key_hash AND is_active = TRUE
      AND (expires_at IS NULL OR expires_at > NOW());
    
    IF v_key_record.key_id IS NOT NULL THEN
        v_success := TRUE;
        v_user_id := v_key_record.user_id;
        UPDATE api_keys SET last_used_at = NOW() WHERE key_id = v_key_record.key_id;
    END IF;
    
    INSERT INTO api_keys_audit (key_id, user_id, action, success, ip_address, created_at)
    VALUES (v_key_record.key_id, v_user_id, p_action, v_success, p_ip_address, NOW());
    
    RETURN v_user_id;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- API usage statistics view
CREATE OR REPLACE VIEW v_api_usage AS
SELECT 
    action,
    success,
    COUNT(*) as total_calls,
    COUNT(CASE WHEN success THEN 1 END) as successful_calls,
    COUNT(CASE WHEN NOT success THEN 1 END) as failed_calls,
    COUNT(DISTINCT user_id) as unique_users
FROM api_keys_audit
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY action, success;