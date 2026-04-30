-- ============================================================================
-- Soft Delete Pattern
-- ============================================================================

-- Soft delete mixin
CREATE TABLE IF NOT EXISTS soft_deletes (
    id SERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    deleted_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_by UUID,
    delete_reason TEXT,
    hard_delete_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
    UNIQUE(entity_type, entity_id)
);

-- Soft delete function
CREATE OR REPLACE FUNCTION soft_delete(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_deleted_by UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO soft_deletes (entity_type, entity_id, deleted_by, delete_reason)
    VALUES (p_entity_type, p_entity_id, p_deleted_by, p_reason);
    
    EXECUTE format('DELETE FROM %I WHERE id = %L', p_entity_type, p_entity_id);
END;
$$ LANGUAGE plpgsql;

-- Restore from soft delete
CREATE OR REPLACE FUNCTION restore_soft_delete(
    p_entity_type TEXT,
    p_entity_id TEXT
) RETURNS VOID AS $$
DECLARE
    v_record JSONB;
BEGIN
    SELECT new_data INTO v_record
    FROM cdc_log
    WHERE table_name = p_entity_type AND new_data->>'id' = p_entity_id
    ORDER BY id DESC LIMIT 1;
    
    IF v_record IS NOT NULL THEN
        EXECUTE format('INSERT INTO %I VALUES %s', p_entity_type, v_record);
        DELETE FROM soft_deletes WHERE entity_type = p_entity_type AND entity_id = p_entity_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Hard delete old records
CREATE OR REPLACE FUNCTION hard_delete_expired() RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM soft_deletes WHERE hard_delete_at < NOW();
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;