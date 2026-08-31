-- ============================================================================
-- Enterprise Data Governance & Compliance
-- ============================================================================

-- Data classification
CREATE TABLE IF NOT EXISTS data_classifications (
    id SERIAL PRIMARY KEY,
    classification_level TEXT CHECK (classification_level IN ('public', 'internal', 'confidential', 'restricted')) NOT NULL UNIQUE,
    description TEXT,
    color_code VARCHAR(7)
);

INSERT INTO data_classifications (classification_level, description, color_code)
VALUES 
    ('public', 'Publicly available', '#00FF00'),
    ('internal', 'Internal use only', '#FFFF00'),
    ('confidential', 'Confidential data', '#FFA500'),
    ('restricted', 'Highly sensitive', '#FF0000')
ON CONFLICT (classification_level) DO NOTHING;

-- Data classification mapping
CREATE TABLE IF NOT EXISTS column_classifications (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    classification_level TEXT REFERENCES data_classifications(classification_level),
    is_encrypted BOOLEAN DEFAULT FALSE,
    is_masked BOOLEAN DEFAULT FALSE,
    UNIQUE(table_name, column_name)
);

-- Compliance reports
CREATE TABLE IF NOT EXISTS compliance_reports (
    id SERIAL PRIMARY KEY,
    report_type TEXT NOT NULL,
    period_start DATE,
    period_end DATE,
    findings JSONB,
    status TEXT CHECK (status IN ('generating', 'completed', 'failed')),
    generated_at TIMESTAMPTZ,
    generated_by UUID
);

-- Generate compliance report
CREATE OR REPLACE FUNCTION generate_compliance_report(
    p_report_type TEXT,
    p_period_start DATE,
    p_period_end DATE
) RETURNS BIGINT AS $$
DECLARE
    v_report_id BIGINT;
    v_findings JSONB;
BEGIN
    INSERT INTO compliance_reports (report_type, period_start, period_end, status)
    VALUES (p_report_type, p_period_start, p_period_end, 'generating')
    RETURNING id INTO v_report_id;
    
    -- Analyze based on type
    IF p_report_type = 'data_access' THEN
        v_findings := jsonb_build_object(
            'total_queries', (SELECT COUNT(*) FROM query_audit_trail WHERE created_at BETWEEN p_period_start AND p_period_end),
            'blocked_queries', (SELECT COUNT(*) FROM query_audit_trail WHERE status = 'blocked' AND created_at BETWEEN p_period_start AND p_period_end),
            'sensitive_access', (SELECT COUNT(*) FROM audit_trail WHERE entity_type = 'users' AND created_at BETWEEN p_period_start AND p_period_end)
        );
    ELSIF p_report_type = 'data_retention' THEN
        v_findings := jsonb_build_object(
            'events_archived', (SELECT COUNT(*) FROM event_store_archive WHERE created_at BETWEEN p_period_start AND p_period_end),
            'policies_applied', (SELECT COUNT(*) FROM data_retention_policies WHERE enabled = TRUE)
        );
    END IF;
    
    UPDATE compliance_reports SET findings = v_findings, status = 'completed', generated_at = NOW()
    WHERE id = v_report_id;
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql;

-- GDPR right to be forgotten
CREATE OR REPLACE FUNCTION gdpr_anonymize_tenant(p_tenant_id UUID) RETURNS VOID AS $$
BEGIN
    -- Anonymize all user data
    UPDATE users SET 
        email = 'redacted_' || user_id || '@redacted.local',
        first_name = 'REDACTED',
        last_name = 'REDACTED',
        password_hash = 'REDACTED'
    WHERE user_id IN (SELECT user_id FROM tenant_users WHERE tenant_id = p_tenant_id);
    
    -- Clear API keys
    DELETE FROM api_keys WHERE tenant_id = p_tenant_id;
    
    -- Anonymize events
    UPDATE event_store SET user_id = NULL WHERE tenant_id = p_tenant_id;
    
    PERFORM log_security_event('gdpr_anonymization', 5, NULL, NULL, 
        jsonb_build_object('tenant_id', p_tenant_id, 'action', 'anonymize'));
END;
$$ LANGUAGE plpgsql;