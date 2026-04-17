-- ============================================================================
-- Saga Orchestrator - Distributed Transaction Management
-- ============================================================================
-- Implements Saga pattern for distributed transactions
-- Commands -> Events -> Compensation on failure
-- ============================================================================

-- ============================================================================
-- SAGA TABLES
-- ============================================================================

-- Saga instance tracking
CREATE TABLE IF NOT EXISTS saga_instances (
    saga_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    saga_type           VARCHAR(128) NOT NULL,
    correlation_id      UUID NOT NULL,
    tenant_id           UUID NOT NULL,
    user_id             UUID,
    status              VARCHAR(32) DEFAULT 'started' 
                        CHECK (status IN ('started', 'running', 'completed', 'compensating', 'compensated', 'failed')),
    current_step        INT DEFAULT 0,
    total_steps         INT NOT NULL,
    input_data          JSONB,
    result_data         JSONB,
    error_message       TEXT,
    started_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Saga steps (commands executed)
CREATE TABLE IF NOT EXISTS saga_steps (
    step_id             BIGSERIAL PRIMARY KEY,
    saga_id             UUID NOT NULL REFERENCES saga_instances(saga_id) ON DELETE CASCADE,
    step_number         INT NOT NULL,
    step_type           VARCHAR(32) NOT NULL CHECK (step_type IN ('action', 'compensation')),
    command_type        VARCHAR(128) NOT NULL,
    command_data        JSONB NOT NULL,
    aggregate_id        UUID,
    event_id            BIGINT REFERENCES event_store(event_id),
    status              VARCHAR(32) DEFAULT 'pending' 
                        CHECK (status IN ('pending', 'executed', 'failed', 'compensated')),
    error_message       TEXT,
    executed_at         TIMESTAMP WITH TIME ZONE,
    compensated_at    TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(saga_id, step_number, step_type)
);

-- Saga definitions (templates)
CREATE TABLE IF NOT EXISTS saga_definitions (
    saga_type           VARCHAR(128) PRIMARY KEY,
    description         TEXT,
    steps_definition    JSONB NOT NULL,  -- Ordered array of step definitions
    timeout_seconds     INT DEFAULT 300,
    max_retries         INT DEFAULT 3,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_saga_instances_status ON saga_instances(status, updated_at);
CREATE INDEX IF NOT EXISTS idx_saga_instances_correlation ON saga_instances(correlation_id);
CREATE INDEX IF NOT EXISTS idx_saga_instances_tenant ON saga_instances(tenant_id);
CREATE INDEX IF NOT EXISTS idx_saga_steps_saga ON saga_steps(saga_id);
CREATE INDEX IF NOT EXISTS idx_saga_steps_status ON saga_steps(status);

-- ============================================================================
-- SAGA ORCHESTRATOR FUNCTIONS
-- ============================================================================

-- Create new saga instance
CREATE OR REPLACE FUNCTION saga_create(
    p_saga_type VARCHAR(128),
    p_correlation_id UUID,
    p_tenant_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_input_data JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    v_saga_id UUID := gen_random_uuid();
    v_definition JSONB;
    v_total_steps INT;
BEGIN
    -- Get saga definition
    SELECT steps_definition INTO v_definition
    FROM saga_definitions
    WHERE saga_type = p_saga_type;
    
    IF v_definition IS NULL THEN
        RAISE EXCEPTION 'Unknown saga type: %', p_saga_type;
    END IF;
    
    v_total_steps := jsonb_array_length(v_definition);
    
    -- Create saga instance
    INSERT INTO saga_instances (
        saga_id, saga_type, correlation_id, tenant_id, user_id,
        status, current_step, total_steps, input_data
    ) VALUES (
        v_saga_id, p_saga_type, p_correlation_id, p_tenant_id, p_user_id,
        'started', 0, v_total_steps, p_input_data
    );
    
    -- Create steps
    FOR i IN 0..v_total_steps - 1 LOOP
        INSERT INTO saga_steps (
            saga_id, step_number, step_type, command_type, command_data, status
        ) SELECT 
            v_saga_id, i + 1, 'action', 
            value->>'command_type',
            value->'command_data',
            'pending'
        FROM jsonb_array_elements(v_definition)
        WITH ORDINALITY AS t(value, ord)
        WHERE ord = i + 1;
    END LOOP;
    
    RETURN v_saga_id;
END;
$$ LANGUAGE plpgsql;

-- Execute next saga step
CREATE OR REPLACE FUNCTION saga_execute_step(
    p_saga_id UUID,
    p_tenant_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_step RECORD;
    v_result BIGINT;
    v_success BOOLEAN := FALSE;
BEGIN
    -- Get next pending step
    SELECT * INTO v_step
    FROM saga_steps
    WHERE saga_id = p_saga_id AND status = 'pending' AND step_type = 'action'
    ORDER BY step_number
    LIMIT 1;
    
    IF v_step IS NULL THEN
        -- No more steps - mark saga as completed
        UPDATE saga_instances
        SET status = 'completed',
            completed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE saga_id = p_saga_id;
        
        RETURN TRUE;
    END IF;
    
    -- Update saga status to running
    UPDATE saga_instances
    SET status = 'running',
        current_step = v_step.step_number,
        updated_at = CURRENT_TIMESTAMP
    WHERE saga_id = p_saga_id;
    
    -- Execute command based on command_type
    BEGIN
        CASE v_step.command_type
            WHEN 'inventory.receive_stock' THEN
                v_result := cmd_inventory_receive_stock(
                    (v_step.command_data->>'aggregate_id')::UUID,
                    p_tenant_id,
                    p_user_id,
                    (v_step.command_data->>'goods_id')::UUID,
                    (v_step.command_data->>'location_id')::UUID,
                    (v_step.command_data->>'qty')::NUMERIC,
                    (v_step.command_data->>'cost')::NUMERIC,
                    (v_step.command_data->>'price')::NUMERIC,
                    v_step.command_data->>'lot_number',
                    (v_step.command_data->>'expiry_date')::DATE,
                    'saga:' || p_saga_id::TEXT,
                    NULL
                );
                
            WHEN 'inventory.issue_stock' THEN
                -- TODO: Handle multiple lots result
                PERFORM cmd_inventory_issue_stock(
                    (v_step.command_data->>'aggregate_id')::UUID,
                    p_tenant_id,
                    p_user_id,
                    (v_step.command_data->>'goods_id')::UUID,
                    (v_step.command_data->>'location_id')::UUID,
                    (v_step.command_data->>'qty')::NUMERIC,
                    'saga:' || p_saga_id::TEXT,
                    NULL
                );
                v_result := 1;
                
            WHEN 'bill.create' THEN
                v_result := cmd_bill_create(
                    (v_step.command_data->>'aggregate_id')::UUID,
                    p_tenant_id,
                    p_user_id,
                    v_step.command_data->>'bill_code',
                    (v_step.command_data->>'bill_date')::DATE,
                    (v_step.command_data->>'person_id')::UUID,
                    (v_step.command_data->>'location_id')::UUID,
                    (v_step.command_data->>'op_kind_id')::UUID,
                    v_step.command_data->>'notes',
                    NULL
                );
                
            WHEN 'bill.add_line' THEN
                v_result := cmd_bill_add_line(
                    (v_step.command_data->>'aggregate_id')::UUID,
                    p_tenant_id,
                    p_user_id,
                    NULL,  -- line_id
                    (v_step.command_data->>'goods_id')::UUID,
                    (v_step.command_data->>'quantity')::NUMERIC,
                    (v_step.command_data->>'price')::NUMERIC,
                    (v_step.command_data->>'discount')::NUMERIC,
                    (v_step.command_data->>'vat_rate')::NUMERIC,
                    NULL
                );
                
            WHEN 'bill.post' THEN
                v_result := cmd_bill_post(
                    (v_step.command_data->>'aggregate_id')::UUID,
                    p_tenant_id,
                    p_user_id,
                    NULL
                );
                
            ELSE
                RAISE EXCEPTION 'Unknown command type: %', v_step.command_type;
        END CASE;
        
        -- Mark step as executed
        UPDATE saga_steps
        SET status = 'executed',
            executed_at = CURRENT_TIMESTAMP,
            event_id = v_result
        WHERE step_id = v_step.step_id;
        
        v_success := TRUE;
        
    EXCEPTION WHEN OTHERS THEN
        -- Mark step as failed
        UPDATE saga_steps
        SET status = 'failed',
            error_message = SQLERRM,
            executed_at = CURRENT_TIMESTAMP
        WHERE step_id = v_step.step_id;
        
        -- Trigger compensation
        PERFORM saga_compensate(p_saga_id, p_tenant_id, p_user_id);
        
        v_success := FALSE;
    END;
    
    RETURN v_success;
END;
$$ LANGUAGE plpgsql;

-- Compensate failed saga
CREATE OR REPLACE FUNCTION saga_compensate(
    p_saga_id UUID,
    p_tenant_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_saga RECORD;
    v_step RECORD;
BEGIN
    -- Get saga info
    SELECT * INTO v_saga
    FROM saga_instances
    WHERE saga_id = p_saga_id;
    
    -- Mark saga as compensating
    UPDATE saga_instances
    SET status = 'compensating',
        updated_at = CURRENT_TIMESTAMP
    WHERE saga_id = p_saga_id;
    
    -- Compensate executed steps in reverse order
    FOR v_step IN
        SELECT * FROM saga_steps
        WHERE saga_id = p_saga_id 
          AND step_type = 'action' 
          AND status = 'executed'
        ORDER BY step_number DESC
    LOOP
        BEGIN
            -- Execute compensation based on command type
            CASE v_step.command_type
                WHEN 'inventory.receive_stock' THEN
                    -- Compensate by creating adjustment
                    PERFORM cmd_inventory_adjust_stock(
                        (v_step.command_data->>'aggregate_id')::UUID,
                        p_tenant_id,
                        p_user_id,
                        (v_step.command_data->>'goods_id')::UUID,
                        (v_step.command_data->>'location_id')::UUID,
                        -((v_step.command_data->>'qty')::NUMERIC),
                        'Saga compensation: ' || p_saga_id::TEXT,
                        'saga-compensation:' || p_saga_id::TEXT,
                        NULL
                    );
                    
                WHEN 'bill.create' THEN
                    -- If bill was posted, cancel it
                    PERFORM cmd_bill_cancel(
                        (v_step.command_data->>'aggregate_id')::UUID,
                        p_tenant_id,
                        p_user_id,
                        'Saga compensation',
                        NULL
                    );
                    
                -- Add other compensations as needed
            END CASE;
            
            -- Mark step as compensated
            UPDATE saga_steps
            SET status = 'compensated',
                compensated_at = CURRENT_TIMESTAMP
            WHERE step_id = v_step.step_id;
            
        EXCEPTION WHEN OTHERS THEN
            -- Log compensation failure but continue
            RAISE WARNING 'Compensation failed for step %: %', v_step.step_id, SQLERRM;
        END;
    END LOOP;
    
    -- Mark saga as compensated
    UPDATE saga_instances
    SET status = 'compensated',
        updated_at = CURRENT_TIMESTAMP
    WHERE saga_id = p_saga_id;
END;
$$ LANGUAGE plpgsql;

-- Get saga status
CREATE OR REPLACE FUNCTION saga_get_status(
    p_saga_id UUID
)
RETURNS TABLE (
    saga_id UUID,
    saga_type VARCHAR(128),
    status VARCHAR(32),
    current_step INT,
    total_steps INT,
    progress_pct NUMERIC,
    started_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        si.saga_id,
        si.saga_type,
        si.status,
        si.current_step,
        si.total_steps,
        ROUND((si.current_step::NUMERIC / NULLIF(si.total_steps, 0)) * 100, 2) AS progress_pct,
        si.started_at,
        si.updated_at
    FROM saga_instances si
    WHERE si.saga_id = p_saga_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SAGA DEFINITIONS
-- ============================================================================

-- Create Sales Order Saga
INSERT INTO saga_definitions (saga_type, description, steps_definition) VALUES
('sales_order', 'Process sales order: reserve stock, create bill, post bill', '[
    {"command_type": "inventory.reserve_stock", "command_data": {"aggregate_id": "${inventory_aggregate}", "goods_id": "${goods_id}", "location_id": "${location_id}", "qty": "${qty}"}},
    {"command_type": "bill.create", "command_data": {"aggregate_id": "${bill_aggregate}", "bill_code": "${bill_code}", "bill_date": "${bill_date}", "person_id": "${person_id}", "location_id": "${location_id}", "op_kind_id": "${op_kind_id}"}},
    {"command_type": "bill.add_line", "command_data": {"aggregate_id": "${bill_aggregate}", "goods_id": "${goods_id}", "quantity": "${qty}", "price": "${price}", "discount": "${discount}", "vat_rate": "${vat_rate}"}},
    {"command_type": "bill.post", "command_data": {"aggregate_id": "${bill_aggregate}"}},
    {"command_type": "inventory.issue_stock", "command_data": {"aggregate_id": "${inventory_aggregate}", "goods_id": "${goods_id}", "location_id": "${location_id}", "qty": "${qty}"}},
    {"command_type": "inventory.release_stock", "command_data": {"reservation_id": "${reservation_id}"}}
]')
ON CONFLICT (saga_type) DO UPDATE SET
    description = EXCLUDED.description,
    steps_definition = EXCLUDED.steps_definition;

-- Create Purchase Order Saga
INSERT INTO saga_definitions (saga_type, description, steps_definition) VALUES
('purchase_order', 'Process purchase order: receive stock, create bill', '[
    {"command_type": "inventory.receive_stock", "command_data": {"aggregate_id": "${inventory_aggregate}", "goods_id": "${goods_id}", "location_id": "${location_id}", "qty": "${qty}", "cost": "${cost}", "price": "${price}", "lot_number": "${lot_number}"}},
    {"command_type": "bill.create", "command_data": {"aggregate_id": "${bill_aggregate}", "bill_code": "${bill_code}", "bill_date": "${bill_date}", "person_id": "${person_id}", "location_id": "${location_id}", "op_kind_id": "${op_kind_id}"}},
    {"command_type": "bill.add_line", "command_data": {"aggregate_id": "${bill_aggregate}", "goods_id": "${goods_id}", "quantity": "${qty}", "price": "${price}", "discount": "${discount}", "vat_rate": "${vat_rate}"}},
    {"command_type": "bill.post", "command_data": {"aggregate_id": "${bill_aggregate}"}}
]')
ON CONFLICT (saga_type) DO UPDATE SET
    description = EXCLUDED.description,
    steps_definition = EXCLUDED.steps_definition;

-- Create Stock Transfer Saga
INSERT INTO saga_definitions (saga_type, description, steps_definition) VALUES
('stock_transfer', 'Transfer stock between locations', '[
    {"command_type": "inventory.issue_stock", "command_data": {"aggregate_id": "${source_inventory_aggregate}", "goods_id": "${goods_id}", "location_id": "${source_location_id}", "qty": "${qty}"}},
    {"command_type": "inventory.receive_stock", "command_data": {"aggregate_id": "${target_inventory_aggregate}", "goods_id": "${goods_id}", "location_id": "${target_location_id}", "qty": "${qty}", "cost": "${cost}", "price": "${price}"}}
]')
ON CONFLICT (saga_type) DO UPDATE SET
    description = EXCLUDED.description,
    steps_definition = EXCLUDED.steps_definition;
