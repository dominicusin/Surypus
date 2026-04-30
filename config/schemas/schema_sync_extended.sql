-- ============================================================================
-- SCHEMA: Data Synchronization (Синхронизация данных)
-- Соответствует C++ классам ObjSyncCore в objsync.cpp
-- ============================================================================

-- Таблица объектов синхронизации
CREATE TABLE IF NOT EXISTS sync_object (
    id              SERIAL PRIMARY KEY,
    object_type     INTEGER NOT NULL,
    object_id       INTEGER NOT NULL,
    local_version   INTEGER DEFAULT 0,
    common_id       VARCHAR(100),
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT so_object_unique UNIQUE (object_type, object_id),
    CONSTRAINT so_version_check CHECK (local_version >= 0)
);

-- Таблица очереди синхронизации
CREATE TABLE IF NOT EXISTS sync_queue (
    id              SERIAL PRIMARY KEY,
    object_type     INTEGER NOT NULL,
    object_id       INTEGER NOT NULL,
    action          VARCHAR(20) NOT NULL,   -- CREATE, UPDATE, DELETE, UNIFY
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, IN_PROGRESS, COMPLETED, FAILED, CONFLICT
    priority        INTEGER DEFAULT 5,      -- 0-10
    error_message   TEXT,
    retry_count     INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT sq_action_check CHECK (action IN ('CREATE', 'UPDATE', 'DELETE', 'UNIFY')),
    CONSTRAINT sq_status_check CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CONFLICT')),
    CONSTRAINT sq_priority_check CHECK (priority >= 0 AND priority <= 10)
);

-- Таблица истории синхронизации
CREATE TABLE IF NOT EXISTS sync_history (
    id              SERIAL PRIMARY KEY,
    object_type     INTEGER NOT NULL,
    object_id       INTEGER NOT NULL,
    action          VARCHAR(20) NOT NULL,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) NOT NULL,
    local_version   INTEGER,
    common_version  INTEGER,
    message         TEXT,
    
    CONSTRAINT sh_action_check CHECK (action IN ('CREATE', 'UPDATE', 'DELETE', 'UNIFY')),
    CONSTRAINT sh_status_check CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CONFLICT'))
);

-- Таблица конфликтов синхронизации
CREATE TABLE IF NOT EXISTS sync_conflict (
    id              SERIAL PRIMARY KEY,
    object_type     INTEGER NOT NULL,
    object_id       INTEGER NOT NULL,
    local_data      JSONB,
    remote_data     JSONB,
    local_timestamp TIMESTAMP,
    remote_timestamp TIMESTAMP,
    resolution      VARCHAR(20),            -- LOCAL, REMOTE, MERGE
    resolved_at     TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT sc_resolution_check CHECK (resolution IN ('LOCAL', 'REMOTE', 'MERGE') OR resolution IS NULL)
);

-- Таблица связей узлов синхронизации
CREATE TABLE IF NOT EXISTS sync_node (
    id              SERIAL PRIMARY KEY,
    node_name       VARCHAR(100) NOT NULL,
    node_type       VARCHAR(50) NOT NULL,   -- MASTER, SLAVE, PEER
    api_endpoint    VARCHAR(500),
    is_active       BOOLEAN DEFAULT TRUE,
    last_sync       TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT sn_name_unique UNIQUE (node_name)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_so_object ON sync_object(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_so_common ON sync_object(common_id);
CREATE INDEX IF NOT EXISTS idx_sq_status ON sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_sq_priority ON sync_queue(priority DESC);
CREATE INDEX IF NOT EXISTS idx_sq_timestamp ON sync_queue(timestamp);
CREATE INDEX IF NOT EXISTS idx_sh_object ON sync_history(object_type, object_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sc_object ON sync_conflict(object_type, object_id);

-- Функция: Рассчитать checksum
CREATE OR REPLACE FUNCTION calculate_checksum(p_data TEXT)
RETURNS INTEGER AS $$
DECLARE
    v_sum INTEGER := 0;
    v_char CHAR;
BEGIN
    FOR i IN 1..LENGTH(p_data) LOOP
        v_char := SUBSTRING(p_data FROM i FOR 1);
        v_sum := v_sum + (ASCII(v_char) * i);
    END LOOP;
    RETURN v_sum;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Получить следующий элемент очереди
CREATE OR REPLACE FUNCTION get_next_sync_item(p_limit INTEGER DEFAULT 1)
RETURNS TABLE (id INTEGER, object_type INTEGER, object_id INTEGER, action VARCHAR, priority INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT sq.id, sq.object_type, sq.object_id, sq.action, sq.priority
    FROM sync_queue sq
    WHERE sq.status = 'PENDING'
    ORDER BY sq.priority DESC, sq.timestamp ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Процедура: Добавить в очередь синхронизации
CREATE OR REPLACE PROCEDURE queue_sync(
    p_object_type INTEGER,
    p_object_id INTEGER,
    p_action VARCHAR,
    p_priority INTEGER DEFAULT 5
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO sync_queue (object_type, object_id, action, priority)
    VALUES (p_object_type, p_object_id, p_action, p_priority)
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'Queued sync: % % %', p_object_type, p_object_id, p_action;
END;
$$;

-- Процедура: Обработать элемент синхронизации
CREATE OR REPLACE PROCEDURE process_sync_item(p_queue_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE sync_queue
    SET status = 'IN_PROGRESS'
    WHERE id = p_queue_id;
    
    -- TODO: Выполнить синхронизацию
    
    UPDATE sync_queue
    SET status = 'COMPLETED'
    WHERE id = p_queue_id;
    
    RAISE NOTICE 'Processed sync item %', p_queue_id;
END;
$$;

-- Процедура: Разрешить конфликт
CREATE OR REPLACE PROCEDURE resolve_sync_conflict(
    p_conflict_id INTEGER,
    p_resolution VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE sync_conflict
    SET resolution = p_resolution,
        resolved_at = CURRENT_TIMESTAMP
    WHERE id = p_conflict_id;
    
    RAISE NOTICE 'Conflict % resolved with %', p_conflict_id, p_resolution;
END;
$$;

-- Представление: Ожидающие синхронизации
CREATE OR REPLACE VIEW v_pending_sync AS
SELECT 
    sq.id,
    sq.object_type,
    sq.object_id,
    sq.action,
    sq.priority,
    sq.timestamp,
    sq.retry_count
FROM sync_queue sq
WHERE sq.status = 'PENDING'
ORDER BY sq.priority DESC, sq.timestamp ASC;

-- Представление: Конфликты синхронизации
CREATE OR REPLACE VIEW v_sync_conflicts AS
SELECT 
    sc.id,
    sc.object_type,
    sc.object_id,
    sc.local_timestamp,
    sc.remote_timestamp,
    sc.resolution,
    sc.resolved_at
FROM sync_conflict sc
WHERE sc.resolved_at IS NULL
ORDER BY sc.created_at DESC;

-- Представление: Статистика синхронизации
CREATE OR REPLACE VIEW v_sync_statistics AS
SELECT 
    action,
    status,
    COUNT(*) AS count,
    MIN(timestamp) AS earliest,
    MAX(timestamp) AS latest
FROM sync_history
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY action, status;
