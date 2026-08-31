-- Backup and recovery helpers
-- Create event store archive table
CREATE TABLE IF NOT EXISTS event_store_archive (LIKE event_store INCLUDING ALL);

-- Archive old events (call periodically)
CREATE OR REPLACE FUNCTION archive_events(
    p_before TIMESTAMP WITH TIME ZONE,
    p_batch_size INT DEFAULT 10000
) RETURNS INT AS $$
DECLARE
    v_archived INT;
BEGIN
    -- Move old events to archive (DELETE has no LIMIT; use a subquery).
    WITH moved AS (
        DELETE FROM event_store
        WHERE ctid IN (
            SELECT ctid FROM event_store
            WHERE created_at < p_before
            ORDER BY created_at
            LIMIT p_batch_size
        )
        RETURNING *
    )
    INSERT INTO event_store_archive
    SELECT * FROM moved;
    
    GET DIAGNOSTICS v_archived = ROW_COUNT;
    RETURN v_archived;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Archive failed: %', SQLERRM;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- Recovery point: rebuild aggregate from events
CREATE OR REPLACE FUNCTION recover_aggregate(
    p_aggregate_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_events JSONB;
BEGIN
    SELECT jsonb_agg(jsonb_build_object(
        'event_type', event_type,
        'event_version', event_version,
        'event_data', event_data,
        'created_at', created_at
    ) ORDER BY event_version)
    INTO v_events
    FROM event_store
    WHERE aggregate_id = p_aggregate_id;
    
    RETURN COALESCE(v_events, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;