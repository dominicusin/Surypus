-- ============================================================================
-- Advanced Database Policy Engine
-- ============================================================================

-- Policy definitions
CREATE TABLE IF NOT EXISTS policies (
    id SERIAL PRIMARY KEY,
    policy_name TEXT UNIQUE NOT NULL,
    policy_type TEXT CHECK (policy_type IN ('retention', 'access', 'security', 'compliance', 'cost')),
    policy_definition JSONB NOT NULL,
    scope JSONB DEFAULT '{}',
    enforcement_mode TEXT CHECK (enforcement_mode IN ('audit', 'enforce', 'warn')) DEFAULT 'audit',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Policy violations
CREATE TABLE IF NOT EXISTS policy_violations (
    id BIGSERIAL PRIMARY KEY,
    policy_id INT REFERENCES policies(id),
    resource_type TEXT,
    resource_id TEXT,
    violation_details JSONB,
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    resolved BOOLEAN DEFAULT FALSE,
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register policies
INSERT INTO policies (policy_name, policy_type, policy_definition, enforcement_mode)
VALUES 
    ('pii_encryption', 'security', '{"fields": ["email", "phone"], "action": "encrypt"}'::JSONB, 'enforce'),
    ('data_retention', 'retention', '{"max_age_days": 2555, "action": "archive"}'::JSONB, 'enforce')
ON CONFLICT (policy_name) DO NOTHING;

-- Check policy compliance
CREATE OR REPLACE FUNCTION check_policy_compliance(
    p_policy_name TEXT,
    p_resource_type TEXT,
    p_resource_id TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_policy RECORD;
    v_compliant BOOLEAN := TRUE;
BEGIN
    SELECT * INTO v_policy FROM policies WHERE policy_name = p_policy_name AND is_active = TRUE;
    
    IF v_policy IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Simplified compliance check
    IF v_policy.enforcement_mode = 'enforce' THEN
        INSERT INTO policy_violations (policy_id, resource_type, resource_id, violation_details)
        VALUES (v_policy.id, p_resource_type, p_resource_id, '{"status": "non_compliant"}'::JSONB);
        v_compliant := FALSE;
    END IF;
    
    RETURN v_compliant;
END;
$$ LANGUAGE plpgsql;