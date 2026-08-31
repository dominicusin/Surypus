-- ============================================================================
-- Security Hardening: Enterprise Edition
-- ============================================================================

-- Audit all DDL operations
CREATE TABLE IF NOT EXISTS ddl_audit_log (
    id BIGSERIAL PRIMARY KEY,
    operation TEXT NOT NULL,
    object_type TEXT,
    object_name TEXT,
    executed_by UUID,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    session_info JSONB DEFAULT '{}'
);

-- DDL trigger
CREATE OR REPLACE FUNCTION audit_ddl() RETURNS EVENT_TRIGGER AS $$
BEGIN
    INSERT INTO ddl_audit_log (operation, object_type, object_name, session_info)
    VALUES (
        TG_TAG,
        TG_TAG,
        NULL,
        jsonb_build_object(
            'current_user', current_user,
            'application_name', current_setting('application_name', TRUE),
            'ip_address', NULL
        )
    );
END;
$$ LANGUAGE plpgsql;

DROP EVENT TRIGGER IF EXISTS audit_ddl_trigger;
CREATE EVENT TRIGGER audit_ddl_trigger
ON DDL_COMMAND_END
EXECUTE FUNCTION audit_ddl();

-- Column-level security (RLS enhancement)
CREATE TABLE IF NOT EXISTS column_policies (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    roles TEXT[],
    mask_function TEXT,
    UNIQUE(table_name, column_name)
);

-- Mask sensitive data
CREATE OR REPLACE FUNCTION mask_sensitive(
    p_value TEXT,
    p_mask_type TEXT DEFAULT 'partial'
) RETURNS TEXT AS $$
BEGIN
    RETURN CASE p_mask_type
        WHEN 'full' THEN '***REDACTED***'
        WHEN 'partial' THEN 
            CASE 
                WHEN p_value IS NULL THEN NULL
                WHEN length(p_value) <= 4 THEN '****'
                ELSE substring(p_value, 1, 2) || '****' || substring(p_value, length(p_value)-1, 2)
            END
        WHEN 'email' THEN 
            CASE
                WHEN p_value IS NULL THEN NULL
                WHEN position('@' IN p_value) > 0 THEN 
                    substring(p_value, 1, 2) || '***@***' || substring(p_value, position('@' IN p_value) + 1)
                ELSE p_value
            END
        ELSE p_value
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Security event log
CREATE TABLE IF NOT EXISTS security_events (
    id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    severity INT CHECK (severity BETWEEN 1 AND 5),
    user_id UUID,
    ip_address INET,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_security_events_date ON security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type);

-- Log security event
CREATE OR REPLACE FUNCTION log_security_event(
    p_event_type TEXT,
    p_severity INT,
    p_user_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_details JSONB DEFAULT '{}'
) RETURNS VOID AS $$
BEGIN
    INSERT INTO security_events (event_type, severity, user_id, ip_address, details)
    VALUES (p_event_type, p_severity, p_user_id, p_ip_address, p_details);
END;
$$ LANGUAGE plpgsql;

-- Brute force detection
CREATE TABLE IF NOT EXISTS login_attempts (
    id SERIAL PRIMARY KEY,
    user_id UUID,
    ip_address INET,
    attempt_count INT DEFAULT 1,
    first_attempt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_attempt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    locked_until TIMESTAMP WITH TIME ZONE
);

CREATE OR REPLACE FUNCTION check_login_attempts(
    p_user_id UUID,
    p_ip_address INET,
    p_max_attempts INT DEFAULT 5
) RETURNS BOOLEAN AS $$
DECLARE
    v_attempts INT;
    v_locked_until TIMESTAMP;
BEGIN
    SELECT attempt_count, locked_until INTO v_attempts, v_locked_until
    FROM login_attempts
    WHERE user_id = p_user_id OR ip_address = p_ip_address
    ORDER BY last_attempt DESC
    LIMIT 1;
    
    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
        RETURN FALSE;
    END IF;
    
    IF v_attempts >= p_max_attempts THEN
        UPDATE login_attempts SET 
            locked_until = NOW() + INTERVAL '30 minutes',
            last_attempt = NOW()
        WHERE user_id = p_user_id OR ip_address = p_ip_address;
        
        PERFORM log_security_event('account_locked', 4, p_user_id, p_ip_address, 
            jsonb_build_object('reason', 'max_attempts_exceeded'));
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;