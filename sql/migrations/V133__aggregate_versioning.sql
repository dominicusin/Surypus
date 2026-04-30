-- Aggregate version tracking for optimistic locking
ALTER TABLE aggregates ADD COLUMN IF NOT EXISTS last_event_id BIGINT;
ALTER TABLE aggregates ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE aggregates ADD COLUMN IF NOT EXISTS lock_token UUID;

-- Safe version check function
CREATE OR REPLACE FUNCTION aggregate_lock(
    p_aggregate_id UUID,
    p_expected_version INT,
    p_lock_token UUID DEFAULT gen_random_uuid()
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_version INT;
    v_locked BOOLEAN := FALSE;
BEGIN
    SELECT current_version, locked_at INTO v_current_version, v_locked
    FROM aggregates WHERE aggregate_id = p_aggregate_id
    FOR UPDATE;
    
    IF v_locked IS NOT NULL AND v_locked > NOW() - INTERVAL '5 seconds' THEN
        RETURN FALSE;
    END IF;
    
    IF v_current_version = p_expected_version THEN
        UPDATE aggregates SET 
            locked_at = NOW(),
            lock_token = p_lock_token
        WHERE aggregate_id = p_aggregate_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Release lock
CREATE OR REPLACE FUNCTION aggregate_unlock(
    p_aggregate_id UUID,
    p_lock_token UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE aggregates SET locked_at = NULL, lock_token = NULL
    WHERE aggregate_id = p_aggregate_id AND lock_token = p_lock_token;
END;
$$ LANGUAGE plpgsql;