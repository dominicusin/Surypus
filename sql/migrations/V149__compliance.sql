-- Compliance: PII detection and handling
CREATE TABLE IF NOT EXISTS pii_detection (
    detection_id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    pii_type TEXT CHECK (pii_type IN ('email', 'phone', 'address', 'ssn', 'credit_card', 'other')),
    sensitivity_level INT CHECK (sensitivity_level BETWEEN 1 AND 5),
    UNIQUE(table_name, column_name)
);

-- Register known PII columns
INSERT INTO pii_detection (table_name, column_name, pii_type, sensitivity_level)
VALUES 
    ('users', 'email', 'email', 3),
    ('users', 'password_hash', 'other', 5),
    ('api_keys', 'key_hash', 'other', 4),
    ('tenant_users', 'roles', 'other', 2)
ON CONFLICT (table_name, column_name) DO NOTHING;

-- PII scan function
CREATE OR REPLACE FUNCTION scan_pii_columns() RETURNS TABLE(table_name TEXT, column_name TEXT, pii_type TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT pd.table_name, pd.column_name, pd.pii_type::TEXT
    FROM pii_detection pd
    WHERE pd.sensitivity_level >= 4;
END;
$$ LANGUAGE plpgsql;

-- Audit trail for compliance
CREATE TABLE IF NOT EXISTS compliance_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    operation TEXT NOT NULL,
    table_name TEXT,
    record_id TEXT,
    user_id UUID,
    changes JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_compliance_audit_date ON compliance_audit(created_at);