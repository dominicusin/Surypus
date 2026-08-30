-- ============================================================================
-- Bill Aggregate - Event Sourcing Implementation
-- ============================================================================
-- Events:
--   - BillCreated
--   - BillLineAdded
--   - BillUpdated
--   - BillPosted
--   - BillCancelled
-- ============================================================================

-- ============================================================================
-- COMMAND HANDLERS
-- ============================================================================

-- Command: Create bill
CREATE OR REPLACE FUNCTION cmd_bill_create(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_bill_code TEXT,
    p_bill_date DATE,
    p_person_id UUID,
    p_location_id UUID,
    p_op_kind_id UUID,
    p_notes TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object(
        'bill_code', p_bill_code,
        'bill_date', p_bill_date,
        'person_id', p_person_id,
        'location_id', p_location_id,
        'op_kind_id', p_op_kind_id,
        'notes', p_notes,
        'status', 'draft',
        'created_at', CURRENT_TIMESTAMP
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Bill',
        'BillCreated',
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

-- Command: Add line to bill
CREATE OR REPLACE FUNCTION cmd_bill_add_line(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_goods_id UUID,
    p_quantity NUMERIC,
    p_price NUMERIC,
    p_discount NUMERIC DEFAULT 0,
    p_vat_rate NUMERIC DEFAULT 20,
    p_line_id UUID DEFAULT gen_random_uuid(),
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
    v_amount NUMERIC;
    v_vat_amount NUMERIC;
    v_line_total NUMERIC;
BEGIN
    -- Calculate line totals
    v_amount := ROUND(p_quantity * p_price * (1 - p_discount / 100), 2);
    v_vat_amount := ROUND(v_amount * p_vat_rate / 100, 2);
    v_line_total := v_amount + v_vat_amount;
    
    v_event_data := jsonb_build_object(
        'line_id', p_line_id,
        'goods_id', p_goods_id,
        'quantity', p_quantity,
        'price', p_price,
        'discount', p_discount,
        'vat_rate', p_vat_rate,
        'amount', v_amount,
        'vat_amount', v_vat_amount,
        'line_total', v_line_total,
        'added_at', CURRENT_TIMESTAMP
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Bill',
        'BillLineAdded',
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

-- Command: Post bill (finalize)
CREATE OR REPLACE FUNCTION cmd_bill_post(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
    v_bill_state JSONB;
BEGIN
    -- Rebuild aggregate state
    v_bill_state := bill_rebuild(p_aggregate_id);
    
    -- Validate bill can be posted
    IF (v_bill_state->>'status') != 'draft' THEN
        RAISE EXCEPTION 'Bill cannot be posted: status is %', v_bill_state->>'status';
    END IF;
    
    IF jsonb_array_length(v_bill_state->'lines') = 0 THEN
        RAISE EXCEPTION 'Bill cannot be posted: no lines';
    END IF;
    
    v_event_data := jsonb_build_object(
        'previous_status', v_bill_state->>'status',
        'posted_at', CURRENT_TIMESTAMP,
        'posted_by', p_user_id,
        'total_amount', (v_bill_state->>'total_amount')::NUMERIC,
        'total_vat', (v_bill_state->>'total_vat')::NUMERIC
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Bill',
        'BillPosted',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        p_expected_version
    );
    
    -- Trigger stock movements for bill lines
    PERFORM cmd_bill_process_stock_movements(p_aggregate_id, p_tenant_id, p_user_id);
    
    -- Create accounting entries
    PERFORM cmd_bill_create_accounting_entries(p_aggregate_id, p_tenant_id, p_user_id);
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Cancel bill
CREATE OR REPLACE FUNCTION cmd_bill_cancel(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
    v_bill_state JSONB;
BEGIN
    v_bill_state := bill_rebuild(p_aggregate_id);
    
    IF (v_bill_state->>'status') != 'posted' THEN
        RAISE EXCEPTION 'Bill cannot be cancelled: status is %', v_bill_state->>'status';
    END IF;
    
    v_event_data := jsonb_build_object(
        'previous_status', v_bill_state->>'status',
        'reason', p_reason,
        'cancelled_at', CURRENT_TIMESTAMP,
        'cancelled_by', p_user_id
    );
    
    v_sequence := event_append(
        p_aggregate_id,
        'Bill',
        'BillCancelled',
        v_event_data,
        p_tenant_id,
        p_user_id,
        NULL,
        NULL,
        p_expected_version
    );
    
    -- Reverse stock movements
    PERFORM cmd_bill_reverse_stock_movements(p_aggregate_id, p_tenant_id, p_user_id);
    
    -- Reverse accounting entries
    PERFORM cmd_bill_reverse_accounting_entries(p_aggregate_id, p_tenant_id, p_user_id);
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INTERNAL COMMANDS
-- ============================================================================

-- Process stock movements for bill
CREATE OR REPLACE FUNCTION cmd_bill_process_stock_movements(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_bill_state JSONB;
    v_line JSONB;
    v_line_id UUID;
    v_inventory_aggregate_id UUID;
BEGIN
    v_bill_state := bill_rebuild(p_aggregate_id);
    
    FOR v_line IN SELECT jsonb_array_elements(v_bill_state->'lines')
    LOOP
        v_line_id := (v_line->>'line_id')::UUID;
        v_inventory_aggregate_id := gen_random_uuid();  -- Get or create inventory aggregate
        
        -- Issue stock for this line
        PERFORM cmd_inventory_issue_stock(
            v_inventory_aggregate_id,
            p_tenant_id,
            p_user_id,
            (v_line->>'goods_id')::UUID,
            (v_bill_state->>'location_id')::UUID,
            (v_line->>'quantity')::NUMERIC,
            'bill:' || p_aggregate_id::TEXT
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reverse stock movements for cancelled bill
CREATE OR REPLACE FUNCTION cmd_bill_reverse_stock_movements(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
    -- In production, would look up original stock movements and reverse them
    -- For now, this is a placeholder
    RAISE NOTICE 'Reversing stock movements for bill %', p_aggregate_id;
END;
$$ LANGUAGE plpgsql;

-- Create accounting entries for bill
CREATE OR REPLACE FUNCTION cmd_bill_create_accounting_entries(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_bill_state JSONB;
    v_total_amount NUMERIC;
    v_total_vat NUMERIC;
BEGIN
    v_bill_state := bill_rebuild(p_aggregate_id);
    v_total_amount := (v_bill_state->>'total_amount')::NUMERIC;
    v_total_vat := (v_bill_state->>'total_vat')::NUMERIC;
    
    -- Debit accounts receivable / credit revenue and VAT payable
    -- This is simplified - real implementation would use proper account mapping
    RAISE NOTICE 'Creating accounting entries for bill %: amount=%, vat=%', 
        p_aggregate_id, v_total_amount, v_total_vat;
END;
$$ LANGUAGE plpgsql;

-- Reverse accounting entries for cancelled bill
CREATE OR REPLACE FUNCTION cmd_bill_reverse_accounting_entries(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE 'Reversing accounting entries for bill %', p_aggregate_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AGGREGATE REBUILD
-- ============================================================================

CREATE OR REPLACE FUNCTION bill_rebuild(
    p_aggregate_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_state JSONB := jsonb_build_object(
        'bill_code', NULL,
        'bill_date', NULL,
        'person_id', NULL,
        'location_id', NULL,
        'op_kind_id', NULL,
        'notes', NULL,
        'status', 'draft',
        'lines', '[]'::JSONB,
        'total_amount', 0,
        'total_vat', 0,
        'version', 0
    );
    v_event RECORD;
    v_lines JSONB;
BEGIN
    FOR v_event IN
        SELECT event_type, event_data
        FROM event_get_by_aggregate(p_aggregate_id)
        ORDER BY event_version
    LOOP
        CASE v_event.event_type
            WHEN 'BillCreated' THEN
                v_state := jsonb_set(v_state, '{bill_code}', to_jsonb(v_event.event_data->>'bill_code'));
                v_state := jsonb_set(v_state, '{bill_date}', to_jsonb(v_event.event_data->>'bill_date'));
                v_state := jsonb_set(v_state, '{person_id}', to_jsonb(v_event.event_data->>'person_id'));
                v_state := jsonb_set(v_state, '{location_id}', to_jsonb(v_event.event_data->>'location_id'));
                v_state := jsonb_set(v_state, '{op_kind_id}', to_jsonb(v_event.event_data->>'op_kind_id'));
                v_state := jsonb_set(v_state, '{notes}', to_jsonb(v_event.event_data->>'notes'));
                
            WHEN 'BillLineAdded' THEN
                v_lines := v_state->'lines';
                v_lines := v_lines || jsonb_build_object(
                    'line_id', v_event.event_data->>'line_id',
                    'goods_id', v_event.event_data->>'goods_id',
                    'quantity', v_event.event_data->>'quantity',
                    'price', v_event.event_data->>'price',
                    'discount', v_event.event_data->>'discount',
                    'vat_rate', v_event.event_data->>'vat_rate',
                    'amount', v_event.event_data->>'amount',
                    'vat_amount', v_event.event_data->>'vat_amount',
                    'line_total', v_event.event_data->>'line_total'
                );
                v_state := jsonb_set(v_state, '{lines}', v_lines);
                
                -- Update totals
                v_state := jsonb_set(v_state, '{total_amount}', 
                    to_jsonb((v_state->>'total_amount')::NUMERIC + (v_event.event_data->>'amount')::NUMERIC));
                v_state := jsonb_set(v_state, '{total_vat}', 
                    to_jsonb((v_state->>'total_vat')::NUMERIC + (v_event.event_data->>'vat_amount')::NUMERIC));
                
            WHEN 'BillPosted' THEN
                v_state := jsonb_set(v_state, '{status}', '"posted"');
                
            WHEN 'BillCancelled' THEN
                v_state := jsonb_set(v_state, '{status}', '"cancelled"');
        END CASE;
        
        v_state := jsonb_set(v_state, '{version}', to_jsonb((v_state->>'version')::INT + 1));
    END LOOP;
    
    RETURN v_state;
END;
$$ LANGUAGE plpgsql;
