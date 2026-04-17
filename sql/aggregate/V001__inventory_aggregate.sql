-- ============================================================================
-- Inventory Aggregate - Event Sourcing Implementation
-- ============================================================================
-- Aggregate: Inventory (Stock management)
-- Events:
--   - StockReceived
--   - StockIssued  
--   - StockAdjusted
--   - StockReserved
--   - StockReleased
--   - LotCreated
--   - LotConsumed
-- ============================================================================

-- Aggregate state type
CREATE TYPE IF NOT EXISTS inventory_state AS (
    location_id UUID,
    goods_id UUID,
    current_qty NUMERIC,
    reserved_qty NUMERIC,
    available_qty NUMERIC,
    lots JSONB,  -- Array of lot objects
    version INT
);

-- ============================================================================
-- COMMAND HANDLERS
-- ============================================================================

-- Command: Receive stock (create lot)
CREATE OR REPLACE FUNCTION cmd_inventory_receive_stock(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_goods_id UUID,
    p_location_id UUID,
    p_qty NUMERIC,
    p_cost NUMERIC,
    p_price NUMERIC,
    p_lot_number TEXT DEFAULT NULL,
    p_expiry_date DATE DEFAULT NULL,
    p_document_ref TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_lot_id UUID := gen_random_uuid();
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    -- Validate inputs
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive';
    END IF;
    IF p_cost < 0 THEN
        RAISE EXCEPTION 'Cost cannot be negative';
    END IF;
    
    -- Build event data
    v_event_data := jsonb_build_object(
        'lot_id', v_lot_id,
        'goods_id', p_goods_id,
        'location_id', p_location_id,
        'qty', p_qty,
        'cost', p_cost,
        'price', p_price,
        'lot_number', p_lot_number,
        'expiry_date', p_expiry_date,
        'document_ref', p_document_ref,
        'received_at', CURRENT_TIMESTAMP
    );
    
    -- Append LotCreated event
    v_sequence := event_append(
        p_aggregate_id,
        'Inventory',
        'LotCreated',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,  -- correlation_id
        NULL,  -- causation_id
        p_expected_version
    );
    
    -- Append StockReceived event
    v_event_data := jsonb_build_object(
        'goods_id', p_goods_id,
        'location_id', p_location_id,
        'lot_id', v_lot_id,
        'qty', p_qty,
        'cost', p_cost,
        'document_ref', p_document_ref
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Inventory',
        'StockReceived',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        NULL  -- Version already checked in first event
    );
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Issue stock (FIFO)
CREATE OR REPLACE FUNCTION cmd_inventory_issue_stock(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_goods_id UUID,
    p_location_id UUID,
    p_qty NUMERIC,
    p_document_ref TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS TABLE (lot_id UUID, qty_used NUMERIC, cost NUMERIC, amount NUMERIC) AS $$
DECLARE
    v_lot RECORD;
    v_remaining NUMERIC := p_qty;
    v_use NUMERIC;
    v_sequence BIGINT;
    v_event_data JSONB;
    v_result TABLE(lot_id UUID, qty_used NUMERIC, cost NUMERIC, amount NUMERIC);
BEGIN
    -- Validate inputs
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive';
    END IF;
    
    -- Check available stock using projection
    IF NOT (SELECT stock_is_available(p_goods_id, p_location_id, p_qty)) THEN
        RAISE EXCEPTION 'Insufficient stock for goods % at location %', p_goods_id, p_location_id;
    END IF;
    
    -- Get lots in FIFO order from projection
    FOR v_lot IN
        SELECT * FROM projection_lots_fifo(p_goods_id, p_location_id, p_qty)
    LOOP
        EXIT WHEN v_remaining <= 0;
        
        v_use := LEAST(v_lot.qty_available, v_remaining);
        
        -- Append LotConsumed event
        v_event_data := jsonb_build_object(
            'lot_id', v_lot.lot_id,
            'goods_id', p_goods_id,
            'location_id', p_location_id,
            'qty', v_use,
            'cost', v_lot.lot_cost,
            'document_ref', p_document_ref,
            'consumed_at', CURRENT_TIMESTAMP
        );
        
        v_sequence := event_append(
            p_aggregate_id,
            'Inventory',
            'LotConsumed',
            v_event_data,
            p_tenant_id,
            p_user_id,
            NULL,
            NULL,
            CASE WHEN v_lot.lot_id = (SELECT lot_id FROM projection_lots_fifo(p_goods_id, p_location_id, p_qty) LIMIT 1) 
                 THEN p_expected_version 
                 ELSE NULL 
            END
        );
        
        -- Append StockIssued event
        v_event_data := jsonb_build_object(
            'goods_id', p_goods_id,
            'location_id', p_location_id,
            'lot_id', v_lot.lot_id,
            'qty', v_use,
            'cost', v_lot.lot_cost,
            'document_ref', p_document_ref
        );
        
        v_sequence := event_append(
            p_aggregate_id,
            'Inventory',
            'StockIssued',
            v_event_data,
            p_tenant_id,
            p_user_id,
            NULL,
            NULL,
            NULL
        );
        
        v_remaining := v_remaining - v_use;
        
        -- Add to result
        lot_id := v_lot.lot_id;
        qty_used := v_use;
        cost := v_lot.lot_cost;
        amount := v_use * v_lot.lot_cost;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Command: Adjust stock (inventory count)
CREATE OR REPLACE FUNCTION cmd_inventory_adjust_stock(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_goods_id UUID,
    p_location_id UUID,
    p_adjustment_qty NUMERIC,
    p_reason TEXT DEFAULT NULL,
    p_document_ref TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object(
        'goods_id', p_goods_id,
        'location_id', p_location_id,
        'adjustment_qty', p_adjustment_qty,
        'reason', p_reason,
        'document_ref', p_document_ref,
        'adjusted_at', CURRENT_TIMESTAMP
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Inventory',
        'StockAdjusted',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        p_expected_version
    );
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Reserve stock
CREATE OR REPLACE FUNCTION cmd_inventory_reserve_stock(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_goods_id UUID,
    p_location_id UUID,
    p_qty NUMERIC,
    p_reservation_type TEXT DEFAULT 'order',
    p_reservation_ref TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_reservation_id UUID := gen_random_uuid();
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive';
    END IF;
    
    -- Check available stock
    IF NOT (SELECT stock_is_available(p_goods_id, p_location_id, p_qty)) THEN
        RAISE EXCEPTION 'Insufficient available stock for reservation';
    END IF;
    
    v_event_data := jsonb_build_object(
        'reservation_id', v_reservation_id,
        'goods_id', p_goods_id,
        'location_id', p_location_id,
        'qty', p_qty,
        'reservation_type', p_reservation_type,
        'reservation_ref', p_reservation_ref,
        'reserved_at', CURRENT_TIMESTAMP
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Inventory',
        'StockReserved',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        p_expected_version
    );
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Release reservation
CREATE OR REPLACE FUNCTION cmd_inventory_release_stock(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_reservation_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object(
        'reservation_id', p_reservation_id,
        'reason', p_reason,
        'released_at', CURRENT_TIMESTAMP
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Inventory',
        'StockReleased',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        p_expected_version
    );
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AGGREGATE REBUILD FUNCTION
-- ============================================================================

-- Rebuild inventory aggregate state from events
CREATE OR REPLACE FUNCTION inventory_rebuild(
    p_aggregate_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_state JSONB := jsonb_build_object(
        'location_id', NULL,
        'goods_id', NULL,
        'current_qty', 0,
        'reserved_qty', 0,
        'available_qty', 0,
        'lots', '[]'::JSONB,
        'reservations', '[]'::JSONB,
        'version', 0
    );
    v_event RECORD;
    v_lots JSONB;
    v_reservations JSONB;
BEGIN
    FOR v_event IN
        SELECT event_type, event_data
        FROM event_get_by_aggregate(p_aggregate_id)
        ORDER BY event_version
    LOOP
        v_lots := v_state->'lots';
        v_reservations := v_state->'reservations';
        
        CASE v_event.event_type
            WHEN 'LotCreated' THEN
                v_lots := v_lots || jsonb_build_object(
                    'lot_id', v_event.event_data->>'lot_id',
                    'qty', (v_event.event_data->>'qty')::NUMERIC,
                    'cost', (v_event.event_data->>'cost')::NUMERIC,
                    'created_at', v_event.event_data->>'received_at'
                );
                v_state := jsonb_set(v_state, '{lots}', v_lots);
                v_state := jsonb_set(v_state, '{current_qty}', 
                    to_jsonb((v_state->>'current_qty')::NUMERIC + (v_event.event_data->>'qty')::NUMERIC));
                
            WHEN 'StockReceived' THEN
                -- Already handled by LotCreated
                NULL;
                
            WHEN 'LotConsumed' THEN
                -- Update lot quantity
                v_lots := (
                    SELECT jsonb_agg(
                        CASE 
                            WHEN (lot->>'lot_id') = (v_event.event_data->>'lot_id')
                            THEN jsonb_set(lot, '{qty}', to_jsonb((lot->>'qty')::NUMERIC - (v_event.event_data->>'qty')::NUMERIC))
                            ELSE lot
                        END
                    )
                    FROM jsonb_array_elements(v_lots) AS lot
                    WHERE (lot->>'qty')::NUMERIC > 0
                );
                v_state := jsonb_set(v_state, '{lots}', v_lots);
                v_state := jsonb_set(v_state, '{current_qty}', 
                    to_jsonb((v_state->>'current_qty')::NUMERIC - (v_event.event_data->>'qty')::NUMERIC));
                
            WHEN 'StockIssued' THEN
                -- Already handled by LotConsumed
                NULL;
                
            WHEN 'StockReserved' THEN
                v_reservations := v_reservations || jsonb_build_object(
                    'reservation_id', v_event.event_data->>'reservation_id',
                    'qty', (v_event.event_data->>'qty')::NUMERIC,
                    'goods_id', v_event.event_data->>'goods_id',
                    'location_id', v_event.event_data->>'location_id'
                );
                v_state := jsonb_set(v_state, '{reservations}', v_reservations);
                v_state := jsonb_set(v_state, '{reserved_qty}', 
                    to_jsonb((v_state->>'reserved_qty')::NUMERIC + (v_event.event_data->>'qty')::NUMERIC));
                
            WHEN 'StockReleased' THEN
                v_reservations := (
                    SELECT jsonb_agg(lot)
                    FROM jsonb_array_elements(v_reservations) AS lot
                    WHERE (lot->>'reservation_id') != (v_event.event_data->>'reservation_id')
                );
                v_state := jsonb_set(v_state, '{reservations}', COALESCE(v_reservations, '[]'::JSONB));
                -- Subtract from reserved (need to look up original qty)
                -- This is simplified; in production would need to track original reservation qty
                
            WHEN 'StockAdjusted' THEN
                v_state := jsonb_set(v_state, '{current_qty}', 
                    to_jsonb((v_state->>'current_qty')::NUMERIC + (v_event.event_data->>'adjustment_qty')::NUMERIC));
        END CASE;
        
        -- Update available qty
        v_state := jsonb_set(v_state, '{available_qty}', 
            to_jsonb((v_state->>'current_qty')::NUMERIC - (v_state->>'reserved_qty')::NUMERIC));
        
        -- Increment version
        v_state := jsonb_set(v_state, '{version}', to_jsonb((v_state->>'version')::INT + 1));
    END LOOP;
    
    RETURN v_state;
END;
$$ LANGUAGE plpgsql;
