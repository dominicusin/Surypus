-- ============================================================================
-- Advanced Cost Management & Billing
-- ============================================================================

-- Cost tracking
CREATE TABLE IF NOT EXISTS cost_tracking (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(tenant_id),
    cost_type TEXT NOT NULL,
    cost_amount NUMERIC NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    billing_period DATE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Resource usage costs
CREATE TABLE IF NOT EXISTS resource_costs (
    id SERIAL PRIMARY KEY,
    resource_type TEXT NOT NULL,
    unit_cost NUMERIC NOT NULL,
    unit_type TEXT NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    effective_from TIMESTAMPTZ DEFAULT NOW()
);

-- Default costs
INSERT INTO resource_costs (resource_type, unit_cost, unit_type)
VALUES 
    ('api_call', 0.001, 'per_call'),
    ('storage_mb_month', 0.023, 'per_mb'),
    ('event_stored', 0.00001, 'per_event'),
    ('snapshot', 0.0001, 'per_snapshot')
ON CONFLICT DO NOTHING;

-- Calculate tenant cost
CREATE OR REPLACE FUNCTION calculate_tenant_cost(
    p_tenant_id UUID,
    p_billing_period DATE
) RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC := 0;
    v_events NUMERIC;
    v_storage NUMERIC;
    v_api_calls NUMERIC;
BEGIN
    -- Event costs
    SELECT COUNT(*) INTO v_events FROM event_store WHERE tenant_id = p_tenant_id;
    v_total := v_total + (v_events * 0.00001);
    
    -- API call costs (estimate)
    SELECT COUNT(*) INTO v_api_calls FROM api_request_log 
    WHERE created_at >= p_billing_period AND created_at < p_billing_period + INTERVAL '1 month';
    v_total := v_total + (v_api_calls * 0.001);
    
    RETURN ROUND(v_total, 2);
END;
$$ LANGUAGE plpgsql;

-- Generate invoice
CREATE OR REPLACE FUNCTION generate_invoice(
    p_tenant_id UUID,
    p_period_start DATE,
    p_period_end DATE
) RETURNS JSONB AS $$
DECLARE
    v_cost NUMERIC;
    v_invoice JSONB;
BEGIN
    v_cost := calculate_tenant_cost(p_tenant_id, p_period_start);
    
    v_invoice := jsonb_build_object(
        'tenant_id', p_tenant_id,
        'period_start', p_period_start,
        'period_end', p_period_end,
        'total_cost', v_cost,
        'currency', 'USD',
        'generated_at', NOW()
    );
    
    INSERT INTO cost_tracking (tenant_id, cost_type, cost_amount, billing_period)
    VALUES (p_tenant_id, 'invoice_total', v_cost, p_period_start);
    
    RETURN v_invoice;
END;
$$ LANGUAGE plpgsql;