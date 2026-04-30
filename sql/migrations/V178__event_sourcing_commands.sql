-- ============================================================================
-- Event Sourcing Commands
-- ============================================================================

-- Command registry
CREATE TABLE IF NOT EXISTS commands (
    id BIGSERIAL PRIMARY KEY,
    command_name TEXT UNIQUE NOT NULL,
    aggregate_type TEXT NOT NULL,
    payload_schema JSONB,
    validation_function TEXT,
    is_enabled BOOLEAN DEFAULT TRUE
);

-- Default commands
INSERT INTO commands (command_name, aggregate_type, is_enabled)
VALUES 
    ('inventory_receive', 'Inventory', TRUE),
    ('inventory_issue', 'Inventory', TRUE),
    ('inventory_adjust', 'Inventory', TRUE),
    ('bill_create', 'Bill', TRUE),
    ('bill_post', 'Bill', TRUE),
    ('person_create', 'Person', TRUE)
ON CONFLICT (command_name) DO NOTHING;

-- Command execution log
CREATE TABLE IF NOT EXISTS command_log (
    id BIGSERIAL PRIMARY KEY,
    command_name TEXT NOT NULL,
    aggregate_id UUID NOT NULL,
    payload JSONB,
    user_id UUID,
    correlation_id UUID,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    status TEXT CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT
);

-- Execute command
CREATE OR REPLACE FUNCTION execute_command(
    p_command_name TEXT,
    p_aggregate_id UUID,
    p_payload JSONB,
    p_user_id UUID DEFAULT NULL,
    p_correlation_id UUID DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_command RECORD;
    v_event_id BIGINT;
    v_log_id BIGINT;
BEGIN
    -- Get command
    SELECT * INTO v_command
    FROM commands
    WHERE command_name = p_command_name AND is_enabled = TRUE;
    
    IF v_command IS NULL THEN
        RAISE EXCEPTION 'Command not found or disabled: %', p_command_name;
    END IF;
    
    -- Log start
    INSERT INTO command_log (command_name, aggregate_id, payload, user_id, correlation_id, status)
    VALUES (p_command_name, p_aggregate_id, p_payload, p_user_id, p_correlation_id, 'processing')
    RETURNING id INTO v_log_id;
    
    BEGIN
        -- Execute appropriate command
        CASE p_command_name
            WHEN 'inventory_receive' THEN
                v_event_id := cmd_inventory_receive_stock(
                    p_aggregate_id,
                    p_payload->>'tenant_id'::UUID,
                    p_user_id,
                    p_payload->>'goods_id'::UUID,
                    p_payload->>'location_id'::UUID,
                    p_payload->>'qty'::NUMERIC,
                    p_payload->>'cost'::NUMERIC,
                    p_payload->>'price'::NUMERIC
                );
            -- Add more commands as needed
            ELSE
                RAISE EXCEPTION 'Command not implemented: %', p_command_name;
        END CASE;
        
        UPDATE command_log SET status = 'completed', completed_at = NOW() WHERE id = v_log_id;
        
    EXCEPTION WHEN OTHERS THEN
        UPDATE command_log SET status = 'failed', error_message = SQLERRM, completed_at = NOW() WHERE id = v_log_id;
        RAISE;
    END;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Pending commands view
CREATE OR REPLACE VIEW v_pending_commands AS
SELECT 
    cl.command_name,
    cl.aggregate_id,
    cl.payload,
    cl.started_at,
    EXTRACT(EPOCH FROM (NOW() - cl.started_at)) as age_seconds,
    cl.status,
    cl.error_message
FROM command_log cl
WHERE cl.status IN ('pending', 'processing')
ORDER BY cl.started_at;