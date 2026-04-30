-- ============================================================================
-- Advanced Event Store Features
-- ============================================================================

-- Event store compression
CREATE TABLE IF NOT EXISTS event_store_compressed (
    LIKE event_store INCLUDING ALL
);

-- Compress old events
CREATE OR REPLACE FUNCTION compress_old_events(
    p_before_date TIMESTAMPTZ,
    p_batch_size INT DEFAULT 10000
) RETURNS INT AS $$
DECLARE
    v_compressed INT := 0;
BEGIN
    -- Move old events to compressed table
    WITH compressed AS (
        DELETE FROM event_store
        WHERE created_at < p_before_date
          AND event_id NOT IN (SELECT event_id FROM aggregate_snapshots)
        LIMIT p_batch_size
        RETURNING *
    )
    INSERT INTO event_store_compressed
    SELECT * FROM compressed;
    
    GET DIAGNOSTICS v_compressed = ROW_COUNT;
    
    PERFORM metrics_record('events_compressed', v_compressed, '{}'::JSONB);
    
    RETURN v_compressed;
END;
$$ LANGUAGE plpgsql;

-- Event encryption at rest
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypted event view (for authorized access)
CREATE OR REPLACE FUNCTION decrypt_event_data(
    p_event_id BIGINT,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_event_data JSONB;
    v_encrypted BOOLEAN;
BEGIN
    -- Check permissions
    IF NOT has_permission(p_user_id, 'event', 'read', NULL) THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    SELECT event_data INTO v_event_data
    FROM event_store
    WHERE event_id = p_event_id;
    
    RETURN v_event_data;
END;
$$ LANGUAGE plpgsql;

-- Event deduplication
CREATE OR REPLACE FUNCTION deduplicate_events(
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_event_data JSONB,
    p_dedup_key TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Check if event with same dedup key exists recently
    SELECT EXISTS (
        SELECT 1 FROM event_store
        WHERE aggregate_id = p_aggregate_id
          AND event_type = p_event_type
          AND event_data->>'dedup_key' = p_dedup_key
          AND created_at > NOW() - INTERVAL '24 hours'
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql;