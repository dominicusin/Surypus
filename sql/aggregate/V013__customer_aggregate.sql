-- ============================================================================
-- Customer Aggregate (CRM domain) - Event Sourcing Implementation
-- Phase 14: ERP domain expansion. Follows the same pattern as the Bill and
-- Goods aggregates, proving the event-sourced framework scales to CRM.
-- ============================================================================
-- Events:
--   - CustomerCreated
--   - CustomerCreditLimitChanged
--   - CustomerRenamed
-- ============================================================================

SELECT event_type_register('CustomerCreated',           'Customer', NULL);
SELECT event_type_register('CustomerCreditLimitChanged','Customer', NULL);
SELECT event_type_register('CustomerRenamed',           'Customer', NULL);

CREATE TABLE IF NOT EXISTS projection_customer (
    customer_id UUID PRIMARY KEY,
    code        TEXT,
    name        TEXT,
    email       TEXT,
    credit_limit NUMERIC(15,2),
    active      BOOLEAN,
    tenant_id   UUID,
    version     INT DEFAULT 0,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Command: Create customer
CREATE OR REPLACE FUNCTION cmd_customer_create(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_code TEXT,
    p_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_credit_limit NUMERIC DEFAULT 0,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object(
        'code', p_code, 'name', p_name, 'email', p_email, 'credit_limit', p_credit_limit
    );
    v_sequence := event_append(
        p_aggregate_id, 'Customer', 'CustomerCreated', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    PERFORM projection_handle_customer(p_aggregate_id, 'CustomerCreated', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Change credit limit
CREATE OR REPLACE FUNCTION cmd_customer_credit_limit(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_new_limit NUMERIC,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('credit_limit', p_new_limit);
    v_sequence := event_append(
        p_aggregate_id, 'Customer', 'CustomerCreditLimitChanged', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    PERFORM projection_handle_customer(p_aggregate_id, 'CustomerCreditLimitChanged', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Rename customer
CREATE OR REPLACE FUNCTION cmd_customer_rename(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_new_name TEXT,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('name', p_new_name);
    v_sequence := event_append(
        p_aggregate_id, 'Customer', 'CustomerRenamed', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    PERFORM projection_handle_customer(p_aggregate_id, 'CustomerRenamed', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Projection: apply a Customer event to the read model.
CREATE OR REPLACE FUNCTION projection_handle_customer(
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_event_data JSONB,
    p_tenant_id UUID
)
RETURNS VOID AS $$
BEGIN
    IF p_event_type = 'CustomerCreated' THEN
        INSERT INTO projection_customer (customer_id, code, name, email, credit_limit, active, tenant_id, version, updated_at)
        VALUES (p_aggregate_id,
                p_event_data->>'code',
                p_event_data->>'name',
                p_event_data->>'email',
                (p_event_data->>'credit_limit')::NUMERIC,
                TRUE,
                p_tenant_id, 1, CURRENT_TIMESTAMP)
        ON CONFLICT (customer_id) DO UPDATE SET
            code = EXCLUDED.code, name = EXCLUDED.name, email = EXCLUDED.email,
            credit_limit = EXCLUDED.credit_limit, version = EXCLUDED.version, updated_at = CURRENT_TIMESTAMP;
    ELSIF p_event_type = 'CustomerCreditLimitChanged' THEN
        UPDATE projection_customer
        SET credit_limit = (p_event_data->>'credit_limit')::NUMERIC,
            version = version + 1, updated_at = CURRENT_TIMESTAMP
        WHERE customer_id = p_aggregate_id;
    ELSIF p_event_type = 'CustomerRenamed' THEN
        UPDATE projection_customer
        SET name = p_event_data->>'name',
            version = version + 1, updated_at = CURRENT_TIMESTAMP
        WHERE customer_id = p_aggregate_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
