-- ============================================================================
-- Advanced Data Contract Enforcement
-- ============================================================================

-- Data contracts
CREATE TABLE IF NOT EXISTS data_contracts (
    id SERIAL PRIMARY KEY,
    contract_name TEXT UNIQUE NOT NULL,
    entity_type TEXT NOT NULL,
    schema JSONB NOT NULL,
    constraints JSONB DEFAULT '[]',
    versioning_enabled BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Contract versions
CREATE TABLE IF NOT EXISTS contract_versions (
    id BIGSERIAL PRIMARY KEY,
    contract_id INT REFERENCES data_contracts(id),
    version INT NOT NULL,
    schema JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(contract_id, version)
);

-- Contract violations
CREATE TABLE IF NOT EXISTS contract_violations (
    id BIGSERIAL PRIMARY KEY,
    contract_id INT REFERENCES data_contracts(id),
    record_id TEXT,
    violation_type TEXT,
    violation_details JSONB,
    detected_at TIMESTAMPTZ DEFAULT NOW()
);

-- Validate contract
CREATE OR REPLACE FUNCTION validate_contract(
    p_contract_name TEXT,
    p_data JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    v_contract RECORD;
    v_valid BOOLEAN := TRUE;
BEGIN
    SELECT * INTO v_contract FROM data_contracts WHERE contract_name = p_contract_name AND is_active = TRUE;
    
    IF v_contract IS NULL THEN
        RETURN TRUE;  -- No contract, allow
    END IF;
    
    -- Simplified validation - check required fields
    FOR key, value IN SELECT * FROM jsonb_each_text(v_contract.schema->'required')
    LOOP
        IF NOT (p_data ? key) THEN
            v_valid := FALSE;
            INSERT INTO contract_violations (contract_id, record_id, violation_type, violation_details)
            VALUES (v_contract.id, NULL, 'missing_field', jsonb_build_object('field', key));
        END IF;
    END LOOP;
    
    RETURN v_valid;
END;
$$ LANGUAGE plpgsql;