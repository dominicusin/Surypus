-- ============================================================================
-- Inventory Aggregate Tests
-- ============================================================================
-- Run with: psql -d surypus -f sql/test/V002__test_inventory_aggregate.sql
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- TEST: Receive Stock Command
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_sequence BIGINT;
    v_lot RECORD;
BEGIN
    -- Receive stock
    v_sequence := cmd_inventory_receive_stock(
        v_aggregate_id,
        v_tenant_id,
        NULL,
        gen_random_uuid(),  -- goods_id
        gen_random_uuid(),  -- location_id
        100.00,             -- qty
        10.00,              -- cost
        15.00,              -- price
        'LOT-001',
        NULL,
        NULL
    );
    
    -- Verify lot was created in projection
    SELECT * INTO v_lot
    FROM projection_fifo_lots
    WHERE aggregate_id = v_aggregate_id
    LIMIT 1;
    
    IF v_lot IS NULL THEN
        RAISE EXCEPTION 'Lot not created';
    END IF;
    
    IF v_lot.qty_received != 100.00 THEN
        RAISE EXCEPTION 'Expected qty_received=100, got %', v_lot.qty_received;
    END IF;
    
    RAISE NOTICE '✓ Receive stock works: sequence=%', v_sequence;
END;
$$;

-- ============================================================================
-- TEST: Issue Stock (FIFO)
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_goods_id UUID := gen_random_uuid();
    v_location_id UUID := gen_random_uuid();
    v_sequence BIGINT;
    v_result RECORD;
    v_balance NUMERIC;
BEGIN
    -- Setup: Receive two lots
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        100.00, 10.00, 15.00, 'LOT-001', NULL, NULL
    );
    
    -- Receive second lot
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        50.00, 12.00, 18.00, 'LOT-002', NULL, NULL
    );
    
    -- Issue 80 units
    FOR v_result IN
        SELECT * FROM cmd_inventory_issue_stock(
            v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id, 80.00, NULL, NULL
        )
    LOOP
        RAISE NOTICE 'Issued from lot %: qty=%, cost=%', v_result.lot_id, v_result.qty_used, v_result.cost;
    END LOOP;
    
    -- Check balance
    SELECT current_qty INTO v_balance
    FROM projection_stock_balance
    WHERE goods_id = v_goods_id AND location_id = v_location_id;
    
    IF v_balance != 70.00 THEN
        RAISE EXCEPTION 'Expected balance=70, got %', v_balance;
    END IF;
    
    RAISE NOTICE '✓ Issue stock (FIFO) works';
END;
$$;

-- ============================================================================
-- TEST: Negative Quantity Validation
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
BEGIN
    BEGIN
        PERFORM cmd_inventory_receive_stock(
            v_aggregate_id, v_tenant_id, NULL,
            gen_random_uuid(), gen_random_uuid(),
            -10.00,  -- Negative quantity
            10.00,
            15.00,
            NULL, NULL, NULL
        );
        RAISE EXCEPTION 'Should have failed with negative quantity';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%positive%' THEN
            RAISE NOTICE '✓ Negative quantity validation works';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;

-- ============================================================================
-- TEST: Insufficient Stock
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_goods_id UUID := gen_random_uuid();
    v_location_id UUID := gen_random_uuid();
BEGIN
    -- Setup: Small amount of stock
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        10.00, 10.00, 15.00, NULL, NULL, NULL
    );
    
    -- Try to issue more than available
    BEGIN
        PERFORM cmd_inventory_issue_stock(
            v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
            100.00, NULL, NULL
        );
        RAISE EXCEPTION 'Should have failed with insufficient stock';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%insufficient%' OR SQLERRM LIKE '%Insufficient%' THEN
            RAISE NOTICE '✓ Insufficient stock validation works';
        ELSE
            RAISE;
        END IF;
    END;
END;
$$;

-- ============================================================================
-- TEST: Stock Adjustment
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_goods_id UUID := gen_random_uuid();
    v_location_id UUID := gen_random_uuid();
    v_sequence BIGINT;
    v_balance NUMERIC;
BEGIN
    -- Setup: Receive stock
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        100.00, 10.00, 15.00, NULL, NULL, NULL
    );
    
    -- Adjust stock (add 20)
    v_sequence := cmd_inventory_adjust_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        20.00, 'Inventory count', NULL, NULL
    );
    
    -- Check balance
    SELECT current_qty INTO v_balance
    FROM projection_stock_balance
    WHERE goods_id = v_goods_id AND location_id = v_location_id;
    
    IF v_balance != 120.00 THEN
        RAISE EXCEPTION 'Expected balance=120 after adjustment, got %', v_balance;
    END IF;
    
    RAISE NOTICE '✓ Stock adjustment works';
END;
$$;

-- ============================================================================
-- TEST: Aggregate Rebuild
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_goods_id UUID := gen_random_uuid();
    v_location_id UUID := gen_random_uuid();
    v_state JSONB;
BEGIN
    -- Setup: Multiple events
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        100.00, 10.00, 15.00, NULL, NULL, NULL
    );
    
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        50.00, 12.00, 18.00, NULL, NULL, NULL
    );
    
    -- Rebuild aggregate
    v_state := inventory_rebuild(v_aggregate_id);
    
    IF (v_state->>'current_qty')::NUMERIC != 150.00 THEN
        RAISE EXCEPTION 'Expected current_qty=150, got %', v_state->>'current_qty';
    END IF;
    
    IF (v_state->>'version')::INT != 4 THEN
        RAISE EXCEPTION 'Expected version=4, got %', v_state->>'version';
    END IF;
    
    RAISE NOTICE '✓ Aggregate rebuild works';
END;
$$;

-- ============================================================================
-- TEST: FIFO Projection Query
-- ============================================================================
DO $$
DECLARE
    v_aggregate_id UUID := gen_random_uuid();
    v_tenant_id UUID := gen_random_uuid();
    v_goods_id UUID := gen_random_uuid();
    v_location_id UUID := gen_random_uuid();
    v_lot RECORD;
    v_count INT := 0;
BEGIN
    -- Setup: Create multiple lots
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        100.00, 10.00, 15.00, 'LOT-A', NULL, NULL
    );
    
    PERFORM cmd_inventory_receive_stock(
        v_aggregate_id, v_tenant_id, NULL, v_goods_id, v_location_id,
        50.00, 12.00, 18.00, 'LOT-B', NULL, NULL
    );
    
    -- Query FIFO lots
    FOR v_lot IN
        SELECT * FROM projection_lots_fifo(v_goods_id, v_location_id, 120.00)
    LOOP
        v_count := v_count + 1;
        RAISE NOTICE 'FIFO lot %: qty_available=%, cost=%', v_count, v_lot.qty_available, v_lot.cost;
    END LOOP;
    
    -- First lot should be used up, second partially
    IF v_count < 2 THEN
        RAISE EXCEPTION 'Expected at least 2 lots in FIFO, got %', v_count;
    END IF;
    
    RAISE NOTICE '✓ FIFO projection query works';
END;
$$;

-- ============================================================================
-- CLEANUP
-- ============================================================================
-- Remove test data
DELETE FROM event_store WHERE aggregate_type = 'Inventory';
DELETE FROM aggregates WHERE aggregate_type = 'Inventory';
DELETE FROM projection_fifo_lots WHERE lot_number IN ('LOT-001', 'LOT-002', 'LOT-A', 'LOT-B');

RAISE NOTICE '';
RAISE NOTICE '========================================';
RAISE NOTICE 'All Inventory Aggregate Tests Passed!';
RAISE NOTICE '========================================';
