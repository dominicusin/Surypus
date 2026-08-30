-- ============================================================================
-- Production Order Aggregate (Production/MRP domain) - Event Sourcing
-- Phase 14: ERP domain expansion. Follows the Bill/Goods/Customer aggregate
-- pattern, proving the framework scales to Production/MRP.
-- ============================================================================
-- Events:
--   - ProductionOrderCreated
--   - ProductionOrderStarted
--   - ProductionOrderCompleted
-- ============================================================================

SELECT event_type_register('ProductionOrderCreated',   'ProductionOrder', NULL);
SELECT event_type_register('ProductionOrderStarted',    'ProductionOrder', NULL);
SELECT event_type_register('ProductionOrderCompleted',  'ProductionOrder', NULL);

CREATE TABLE IF NOT EXISTS projection_production_order (
    order_id     UUID PRIMARY KEY,
    number       TEXT,
    product_id   BIGINT,
    qty          BIGINT,
    due_date     DATE,
    status       INT DEFAULT 0,
    tenant_id    UUID,
    version      INT DEFAULT 0,
    updated_at   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Command: Create production order
CREATE OR REPLACE FUNCTION cmd_production_order_create(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_number TEXT,
    p_product_id BIGINT,
    p_qty BIGINT,
    p_due_date DATE DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE v_event_data JSONB; v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('number', p_number, 'product_id', p_product_id, 'qty', p_qty, 'due_date', to_jsonb(p_due_date));
    v_sequence := event_append(p_aggregate_id, 'ProductionOrder', 'ProductionOrderCreated', v_event_data, p_tenant_id, p_user_id, NULL, NULL, p_expected_version);
    PERFORM projection_handle_production_order(p_aggregate_id, 'ProductionOrderCreated', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Start production
CREATE OR REPLACE FUNCTION cmd_production_order_start(
    p_aggregate_id UUID, p_tenant_id UUID, p_user_id UUID, p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE v_event_data JSONB; v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('status', 1);
    v_sequence := event_append(p_aggregate_id, 'ProductionOrder', 'ProductionOrderStarted', v_event_data, p_tenant_id, p_user_id, NULL, NULL, p_expected_version);
    PERFORM projection_handle_production_order(p_aggregate_id, 'ProductionOrderStarted', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Complete production
CREATE OR REPLACE FUNCTION cmd_production_order_complete(
    p_aggregate_id UUID, p_tenant_id UUID, p_user_id UUID, p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE v_event_data JSONB; v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('status', 2);
    v_sequence := event_append(p_aggregate_id, 'ProductionOrder', 'ProductionOrderCompleted', v_event_data, p_tenant_id, p_user_id, NULL, NULL, p_expected_version);
    PERFORM projection_handle_production_order(p_aggregate_id, 'ProductionOrderCompleted', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Projection: apply a ProductionOrder event to the read model.
CREATE OR REPLACE FUNCTION projection_handle_production_order(
    p_aggregate_id UUID, p_event_type TEXT, p_event_data JSONB, p_tenant_id UUID
)
RETURNS VOID AS $$
BEGIN
    IF p_event_type = 'ProductionOrderCreated' THEN
        INSERT INTO projection_production_order (order_id, number, product_id, qty, due_date, status, tenant_id, version, updated_at)
        VALUES (p_aggregate_id, p_event_data->>'number', (p_event_data->>'product_id')::BIGINT, (p_event_data->>'qty')::BIGINT,
                (p_event_data->>'due_date')::DATE, 0, p_tenant_id, 1, CURRENT_TIMESTAMP)
        ON CONFLICT (order_id) DO UPDATE SET number=EXCLUDED.number, product_id=EXCLUDED.product_id, qty=EXCLUDED.qty,
            due_date=EXCLUDED.due_date, version=EXCLUDED.version, updated_at=CURRENT_TIMESTAMP;
    ELSIF p_event_type = 'ProductionOrderStarted' THEN
        UPDATE projection_production_order SET status=1, version=version+1, updated_at=CURRENT_TIMESTAMP WHERE order_id=p_aggregate_id;
    ELSIF p_event_type = 'ProductionOrderCompleted' THEN
        UPDATE projection_production_order SET status=2, version=version+1, updated_at=CURRENT_TIMESTAMP WHERE order_id=p_aggregate_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
