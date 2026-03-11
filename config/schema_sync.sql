-- =================================================================
-- Sync System - Синхронизация данных
-- =================================================================
-- Analog: OpenPapyrus pplib/objsync.cpp (PPObjSync)

-- Sync Node (узлы синхронизации)
CREATE TABLE IF NOT EXISTS sync_node (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    url TEXT NOT NULL,                   -- URL или путь к базе
    type SMALLINT NOT NULL DEFAULT 0,    -- 0=Pull, 1=Push, 2=Bidirect
    flags INTEGER DEFAULT 0,             -- SYNCF_XXX
    last_sync TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_node_type ON sync_node(type);
CREATE INDEX IF NOT EXISTS idx_sync_node_flags ON sync_node(flags);

-- Sync Queue (очередь синхронизации)
CREATE TABLE IF NOT EXISTS sync_queue (
    id BIGSERIAL PRIMARY KEY,
    node_id BIGINT NOT NULL REFERENCES sync_node(id) ON DELETE CASCADE,
    obj_type BIGINT NOT NULL,            -- PPOBJ_XXX
    obj_id BIGINT NOT NULL,
    operation SMALLINT NOT NULL,         -- 0=Insert, 1=Update, 2=Delete
    data JSONB,                          -- Данные объекта
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status SMALLINT NOT NULL DEFAULT 0,  -- 0=Pending, 1=InProgress, 2=Completed, 3=Failed, 4=Conflict
    attempts INT DEFAULT 0,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_node ON sync_queue(node_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_obj ON sync_queue(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_timestamp ON sync_queue(timestamp);

-- =================================================================
-- Functions
-- =================================================================

-- Add item to sync queue
CREATE OR REPLACE FUNCTION add_to_sync_queue(BIGINT, BIGINT, BIGINT, SMALLINT, JSONB)
RETURNS BIGINT AS $$
DECLARE
    p_node_id ALIAS FOR $1;
    p_obj_type ALIAS FOR $2;
    p_obj_id ALIAS FOR $3;
    p_operation ALIAS FOR $4;
    p_data ALIAS FOR $5;
    v_item_id BIGINT;
BEGIN
    INSERT INTO sync_queue (node_id, obj_type, obj_id, operation, data, status)
    VALUES (p_node_id, p_obj_type, p_obj_id, p_operation, p_data, 0)
    RETURNING id INTO v_item_id;
    
    RETURN v_item_id;
END;
$$ LANGUAGE plpgsql;

-- Get pending sync items for node
CREATE OR REPLACE FUNCTION get_pending_sync_items(BIGINT, INT)
RETURNS TABLE (id BIGINT, obj_type BIGINT, obj_id BIGINT, 
               operation SMALLINT, data JSONB, timestamp TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY
    SELECT sq.id, sq.obj_type, sq.obj_id, sq.operation, sq.data, sq.timestamp
    FROM sync_queue sq
    WHERE sq.node_id = $1 
      AND sq.status = 0 
      AND sq.attempts < $2
    ORDER BY sq.timestamp
    LIMIT 100;
END;
$$ LANGUAGE plpgsql STABLE;

-- Mark item as in progress
CREATE OR REPLACE FUNCTION start_sync_item(BIGINT)
RETURNS VOID AS $$
BEGIN
    UPDATE sync_queue
    SET status = 1, updated_at = NOW()
    WHERE id = $1 AND status = 0;
END;
$$ LANGUAGE plpgsql;

-- Complete sync item
CREATE OR REPLACE FUNCTION complete_sync_item(BIGINT, TEXT)
RETURNS VOID AS $$
DECLARE
    p_item_id ALIAS FOR $1;
    p_error ALIAS FOR $2;
BEGIN
    UPDATE sync_queue
    SET status = CASE WHEN p_error IS NULL THEN 2 ELSE 3 END,
        error = p_error,
        updated_at = NOW()
    WHERE id = p_item_id;
END;
$$ LANGUAGE plpgsql;

-- Retry failed items
CREATE OR REPLACE FUNCTION retry_failed_sync(INT)
RETURNS BIGINT AS $$
DECLARE
    p_max_attempts ALIAS FOR $1;
    v_count BIGINT;
BEGIN
    UPDATE sync_queue
    SET status = 0, error = NULL, updated_at = NOW()
    WHERE status = 3 AND attempts < p_max_attempts;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_sync_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_sync_node_update
    BEFORE UPDATE ON sync_node
    FOR EACH ROW EXECUTE FUNCTION update_sync_timestamp();

CREATE TRIGGER tr_sync_queue_update
    BEFORE UPDATE ON sync_queue
    FOR EACH ROW EXECUTE FUNCTION update_sync_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE sync_node IS 'Узлы синхронизации (аналог SyncCore)';
COMMENT ON TABLE sync_queue IS 'Очередь синхронизации';
COMMENT ON sync_node.type IS 'Тип: 0=Выгрузка, 1=Загрузка, 2=Двусторонняя';
COMMENT ON sync_node.flags IS 'Флаги: 1=Активен, 2=Центральный, 4=Автосинхронизация';
COMMENT ON sync_queue.status IS 'Статус: 0=Ожидает, 1=В процессе, 2=Завершено, 3=Ошибка, 4=Конфликт';
COMMENT ON sync_queue.operation IS 'Операция: 0=Insert, 1=Update, 2=Delete';
