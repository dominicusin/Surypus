-- ============================================================================
-- FIFO Projection - Read Model
-- ============================================================================
-- Projection that maintains FIFO lot availability
-- Used for stock issuance and cost calculation
-- ============================================================================

-- Projection table for FIFO lots
CREATE TABLE IF NOT EXISTS projection_fifo_lots (
    lot_id              UUID PRIMARY KEY,
    goods_id            UUID NOT NULL,
    location_id         UUID NOT NULL,
    qty_received        NUMERIC NOT NULL,
    qty_remaining       NUMERIC NOT NULL,
    lot_cost            NUMERIC NOT NULL,
    lot_price           NUMERIC,
    lot_number          TEXT,
    expiry_date         DATE,
    received_at         TIMESTAMP WITH TIME ZONE NOT NULL,
    document_ref        TEXT,
    aggregate_id        UUID NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT qty_remaining_check CHECK (qty_remaining >= 0),
    CONSTRAINT qty_not_exceeds_received CHECK (qty_remaining <= qty_received)
);

-- Stock balance projection
CREATE TABLE IF NOT EXISTS projection_stock_balance (
    goods_id            UUID NOT NULL,
    location_id         UUID NOT NULL,
    tenant_id           UUID NOT NULL,
    current_qty         NUMERIC NOT NULL DEFAULT 0,
    reserved_qty        NUMERIC NOT NULL DEFAULT 0,
    available_qty       NUMERIC NOT NULL DEFAULT 0,
    total_cost          NUMERIC DEFAULT 0,
    total_value         NUMERIC DEFAULT 0,
    avg_cost            NUMERIC GENERATED ALWAYS AS (CASE WHEN current_qty > 0 THEN total_cost / current_qty ELSE 0 END) STORED,
    last_movement_at    TIMESTAMP WITH TIME ZONE,
    aggregate_id        UUID NOT NULL,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (goods_id, location_id)
);

-- Index for FIFO ordering
CREATE INDEX IF NOT EXISTS idx_fifo_lots_order 
    ON projection_fifo_lots(goods_id, location_id, received_at ASC, lot_id ASC);

CREATE INDEX IF NOT EXISTS idx_fifo_lots_available 
    ON projection_fifo_lots(goods_id, location_id) WHERE qty_remaining > 0;

CREATE INDEX IF NOT EXISTS idx_stock_balance_tenant 
    ON projection_stock_balance(tenant_id);

-- ============================================================================
-- PROJECTION HANDLERS
-- ============================================================================

-- Handle LotCreated event
CREATE OR REPLACE FUNCTION projection_handle_lot_created(
    p_event_data JSONB,
    p_aggregate_id UUID
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO projection_fifo_lots (
        lot_id, goods_id, location_id, qty_received, qty_remaining,
        lot_cost, lot_price, lot_number, expiry_date, received_at,
        document_ref, aggregate_id
    ) VALUES (
        (p_event_data->>'lot_id')::UUID,
        (p_event_data->>'goods_id')::UUID,
        (p_event_data->>'location_id')::UUID,
        (p_event_data->>'qty')::NUMERIC,
        (p_event_data->>'qty')::NUMERIC,
        (p_event_data->>'cost')::NUMERIC,
        (p_event_data->>'price')::NUMERIC,
        p_event_data->>'lot_number',
        (p_event_data->>'expiry_date')::DATE,
        (p_event_data->>'received_at')::TIMESTAMP WITH TIME ZONE,
        p_event_data->>'document_ref',
        p_aggregate_id
    );
    
    -- Update stock balance
    INSERT INTO projection_stock_balance (
        goods_id, location_id, tenant_id, current_qty, available_qty,
        total_cost, last_movement_at, aggregate_id
    )
    SELECT 
        (p_event_data->>'goods_id')::UUID,
        (p_event_data->>'location_id')::UUID,
        (SELECT tenant_id FROM aggregates WHERE aggregate_id = p_aggregate_id),
        (p_event_data->>'qty')::NUMERIC,
        (p_event_data->>'qty')::NUMERIC,
        (p_event_data->>'qty')::NUMERIC * (p_event_data->>'cost')::NUMERIC,
        (p_event_data->>'received_at')::TIMESTAMP WITH TIME ZONE,
        p_aggregate_id
    ON CONFLICT (goods_id, location_id) DO UPDATE SET
        current_qty = projection_stock_balance.current_qty + (p_event_data->>'qty')::NUMERIC,
        available_qty = projection_stock_balance.available_qty + (p_event_data->>'qty')::NUMERIC,
        total_cost = projection_stock_balance.total_cost + ((p_event_data->>'qty')::NUMERIC * (p_event_data->>'cost')::NUMERIC),
        last_movement_at = (p_event_data->>'received_at')::TIMESTAMP WITH TIME ZONE,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Handle LotConsumed event
CREATE OR REPLACE FUNCTION projection_handle_lot_consumed(
    p_event_data JSONB,
    p_aggregate_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_goods_id UUID := (p_event_data->>'goods_id')::UUID;
    v_location_id UUID := (p_event_data->>'location_id')::UUID;
    v_qty NUMERIC := (p_event_data->>'qty')::NUMERIC;
    v_cost NUMERIC := (p_event_data->>'cost')::NUMERIC;
    v_consumed_at TIMESTAMP WITH TIME ZONE := COALESCE(
        (p_event_data->>'consumed_at')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP
    );
BEGIN
    -- Update lot remaining quantity
    UPDATE projection_fifo_lots
    SET qty_remaining = qty_remaining - v_qty,
        updated_at = CURRENT_TIMESTAMP
    WHERE lot_id = (p_event_data->>'lot_id')::UUID;
    
    -- Update stock balance
    UPDATE projection_stock_balance
    SET current_qty = current_qty - v_qty,
        available_qty = available_qty - v_qty,
        total_cost = total_cost - (v_qty * v_cost),
        last_movement_at = v_consumed_at,
        updated_at = CURRENT_TIMESTAMP
    WHERE goods_id = v_goods_id AND location_id = v_location_id;
END;
$$ LANGUAGE plpgsql;

-- Handle StockReserved event
CREATE OR REPLACE FUNCTION projection_handle_stock_reserved(
    p_event_data JSONB
)
RETURNS VOID AS $$
DECLARE
    v_goods_id UUID := (p_event_data->>'goods_id')::UUID;
    v_location_id UUID := (p_event_data->>'location_id')::UUID;
    v_qty NUMERIC := (p_event_data->>'qty')::NUMERIC;
BEGIN
    UPDATE projection_stock_balance
    SET reserved_qty = reserved_qty + v_qty,
        available_qty = available_qty - v_qty,
        updated_at = CURRENT_TIMESTAMP
    WHERE goods_id = v_goods_id AND location_id = v_location_id;
END;
$$ LANGUAGE plpgsql;

-- Handle StockReleased event
CREATE OR REPLACE FUNCTION projection_handle_stock_released(
    p_event_data JSONB
)
RETURNS VOID AS $$
BEGIN
    -- In a real implementation, would need to look up the original reservation
    -- to know the quantity. For now, this is a placeholder.
    -- In production, maintain a separate reservations table.
    NULL;
END;
$$ LANGUAGE plpgsql;

-- Handle StockAdjusted event
CREATE OR REPLACE FUNCTION projection_handle_stock_adjusted(
    p_event_data JSONB
)
RETURNS VOID AS $$
DECLARE
    v_goods_id UUID := (p_event_data->>'goods_id')::UUID;
    v_location_id UUID := (p_event_data->>'location_id')::UUID;
    v_adjustment NUMERIC := (p_event_data->>'adjustment_qty')::NUMERIC;
BEGIN
    UPDATE projection_stock_balance
    SET current_qty = current_qty + v_adjustment,
        available_qty = available_qty + v_adjustment,
        updated_at = CURRENT_TIMESTAMP
    WHERE goods_id = v_goods_id AND location_id = v_location_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- QUERY FUNCTIONS (READ MODEL API)
-- ============================================================================

-- Get FIFO lots for goods issuance
CREATE OR REPLACE FUNCTION projection_lots_fifo(
    p_goods_id UUID,
    p_location_id UUID,
    p_qty_needed NUMERIC
)
RETURNS TABLE (
    lot_id UUID,
    qty_available NUMERIC,
    lot_cost NUMERIC,
    lot_price NUMERIC,
    expiry_date DATE
) AS $$
BEGIN
    RETURN QUERY
    WITH fifo_lots AS (
        SELECT 
            fl.lot_id,
            fl.qty_remaining AS qty_available,
            fl.lot_cost,
            fl.lot_price,
            fl.expiry_date,
            fl.received_at,
            SUM(fl.qty_remaining) OVER (ORDER BY fl.received_at ASC, fl.lot_id ASC) AS running_total
        FROM projection_fifo_lots fl
        WHERE fl.goods_id = p_goods_id
          AND fl.location_id = p_location_id
          AND fl.qty_remaining > 0
    )
    SELECT 
        fl.lot_id,
        LEAST(fl.qty_available, p_qty_needed - COALESCE(
            LAG(fl.running_total) OVER (ORDER BY fl.received_at, fl.lot_id), 
            0
        )) AS qty_available,
        fl.lot_cost,
        fl.lot_price,
        fl.expiry_date
    FROM fifo_lots fl
    WHERE fl.running_total - fl.qty_available < p_qty_needed
    ORDER BY fl.received_at ASC, fl.lot_id ASC;
END;
$$ LANGUAGE plpgsql;

-- Check if stock is available
CREATE OR REPLACE FUNCTION stock_is_available(
    p_goods_id UUID,
    p_location_id UUID,
    p_qty NUMERIC
)
RETURNS BOOLEAN AS $$
DECLARE
    v_available NUMERIC;
BEGIN
    SELECT available_qty INTO v_available
    FROM projection_stock_balance
    WHERE goods_id = p_goods_id AND location_id = p_location_id;
    
    RETURN COALESCE(v_available, 0) >= p_qty;
END;
$$ LANGUAGE plpgsql;

-- Get stock balance
CREATE OR REPLACE FUNCTION stock_get_balance(
    p_goods_id UUID DEFAULT NULL,
    p_location_id UUID DEFAULT NULL,
    p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
    goods_id UUID,
    location_id UUID,
    current_qty NUMERIC,
    reserved_qty NUMERIC,
    available_qty NUMERIC,
    avg_cost NUMERIC,
    total_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sb.goods_id,
        sb.location_id,
        sb.current_qty,
        sb.reserved_qty,
        sb.available_qty,
        sb.avg_cost,
        sb.total_cost AS total_value
    FROM projection_stock_balance sb
    WHERE (p_goods_id IS NULL OR sb.goods_id = p_goods_id)
      AND (p_location_id IS NULL OR sb.location_id = p_location_id)
      AND (p_tenant_id IS NULL OR sb.tenant_id = p_tenant_id)
    ORDER BY sb.goods_id, sb.location_id;
END;
$$ LANGUAGE plpgsql;

-- Get lot details
CREATE OR REPLACE FUNCTION stock_get_lots(
    p_goods_id UUID DEFAULT NULL,
    p_location_id UUID DEFAULT NULL,
    p_only_available BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    lot_id UUID,
    goods_id UUID,
    location_id UUID,
    lot_number TEXT,
    qty_received NUMERIC,
    qty_remaining NUMERIC,
    lot_cost NUMERIC,
    expiry_date DATE,
    received_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fl.lot_id,
        fl.goods_id,
        fl.location_id,
        fl.lot_number,
        fl.qty_received,
        fl.qty_remaining,
        fl.lot_cost,
        fl.expiry_date,
        fl.received_at
    FROM projection_fifo_lots fl
    WHERE (p_goods_id IS NULL OR fl.goods_id = p_goods_id)
      AND (p_location_id IS NULL OR fl.location_id = p_location_id)
      AND (NOT p_only_available OR fl.qty_remaining > 0)
    ORDER BY fl.received_at ASC, fl.lot_id ASC;
END;
$$ LANGUAGE plpgsql;

-- Get low stock report
CREATE OR REPLACE FUNCTION stock_get_low_items(
    p_min_qty NUMERIC DEFAULT 10,
    p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
    goods_id UUID,
    location_id UUID,
    current_qty NUMERIC,
    reorder_qty NUMERIC
) AS $$
BEGIN
    -- In production, would join with goods table to get reorder point
    RETURN QUERY
    SELECT 
        sb.goods_id,
        sb.location_id,
        sb.current_qty,
        p_min_qty AS reorder_qty
    FROM projection_stock_balance sb
    WHERE sb.available_qty < p_min_qty
      AND (p_tenant_id IS NULL OR sb.tenant_id = p_tenant_id)
    ORDER BY sb.available_qty ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PROJECTION REGISTRATION
-- ============================================================================

-- Register this projection
SELECT projection_register('inventory_fifo_projection', 'standard', 'projection_handle_lot_created');

-- Register event handlers
INSERT INTO projection_handlers (projection_id, event_type, handler_order)
SELECT 
    p.projection_id,
    'LotCreated',
    1
FROM projections p
WHERE p.projection_name = 'inventory_fifo_projection'
ON CONFLICT (projection_id, event_type) DO NOTHING;

INSERT INTO projection_handlers (projection_id, event_type, handler_order)
SELECT 
    p.projection_id,
    'LotConsumed',
    2
FROM projections p
WHERE p.projection_name = 'inventory_fifo_projection'
ON CONFLICT (projection_id, event_type) DO NOTHING;
