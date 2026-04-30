-- ============================================================================
-- Advanced Data Quality
-- ============================================================================

-- Data quality rules
CREATE TABLE IF NOT EXISTS data_quality_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    rule_type TEXT CHECK (rule_type IN ('not_null', 'unique', 'range', 'regex', 'custom')),
    rule_definition JSONB NOT NULL,
    severity TEXT CHECK (severity IN ('critical', 'warning', 'info')) DEFAULT 'warning',
    is_active BOOLEAN DEFAULT TRUE
);

-- Quality check results
CREATE TABLE IF NOT EXISTS quality_check_results (
    id BIGSERIAL PRIMARY KEY,
    rule_id INT REFERENCES data_quality_rules(id),
    check_passed BOOLEAN,
    failed_count INT DEFAULT 0,
    sample_data JSONB,
    checked_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register rules
INSERT INTO data_quality_rules (rule_name, table_name, column_name, rule_type, rule_definition)
VALUES 
    ('tenant_id_not_null', 'event_store', 'tenant_id', 'not_null', '{}'::JSONB),
    ('aggregate_id_unique', 'aggregates', 'aggregate_id', 'unique', '{}'::JSONB),
    ('event_type_valid', 'event_store', 'event_type', 'regex', '{"pattern": "^[A-Z]"}'::JSONB)
ON CONFLICT (rule_name) DO NOTHING;

-- Run quality check
CREATE OR REPLACE FUNCTION run_quality_check(
    p_rule_id INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_rule RECORD;
    v_failed_count INT;
    v_passed BOOLEAN;
BEGIN
    SELECT * INTO v_rule FROM data_quality_rules WHERE id = p_rule_id AND is_active = TRUE;
    
    IF v_rule IS NULL THEN
        RETURN NULL;
    END IF;
    
    CASE v_rule.rule_type
        WHEN 'not_null' THEN
            EXECUTE format('SELECT COUNT(*) FROM %I WHERE %I IS NULL', v_rule.table_name, v_rule.column_name)
            INTO v_failed_count;
        WHEN 'unique' THEN
            EXECUTE format('SELECT COUNT(*) - COUNT(DISTINCT %I) FROM %I', v_rule.column_name, v_rule.table_name)
            INTO v_failed_count;
        ELSE
            v_failed_count := 0;
    END CASE;
    
    v_passed := v_failed_count = 0;
    
    INSERT INTO quality_check_results (rule_id, check_passed, failed_count)
    VALUES (p_rule_id, v_passed, v_failed_count);
    
    RETURN v_passed;
END;
$$ LANGUAGE plpgsql;