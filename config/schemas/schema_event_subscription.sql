-- =============================================================================
-- ПОДПИСКИ НА СОБЫТИЯ
-- Соответствуют Core.Event.EventSubscription
-- Аналог: PPOBJ_EVENTSUBSCRIPTION
-- =============================================================================

-- =============================================================================
-- Event Subscription (Подписка)
-- =============================================================================
CREATE TABLE IF NOT EXISTS event_subscription (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    event_type INT NOT NULL,  -- PPACN_*
    object_type INT DEFAULT 0,  -- PPOBJ_*
    object_id INT DEFAULT 0,
    user_id INT DEFAULT 0,
    flags INT DEFAULT 0,  -- 1:Отключена
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_subscription_dates CHECK (start_date <= end_date)
);

CREATE INDEX idx_event_subscription_event ON event_subscription(event_type);
CREATE INDEX idx_event_subscription_object ON event_subscription(object_type, object_id);
CREATE INDEX idx_event_subscription_user ON event_subscription(user_id);
CREATE INDEX idx_event_subscription_dates ON event_subscription(start_date, end_date);

-- =============================================================================
-- Event Queue (Очередь событий)
-- =============================================================================
CREATE TABLE IF NOT EXISTS event_queue (
    id SERIAL PRIMARY KEY,
    subscription_id INT NOT NULL REFERENCES event_subscription(id),
    event_type INT NOT NULL,
    object_type INT DEFAULT 0,
    object_id INT DEFAULT 0,
    event_data JSONB,
    status INT DEFAULT 0,  -- 0:Pending, 1:Processing, 2:Completed, 3:Failed, 4:Cancelled
    retry_count INT DEFAULT 0 CHECK (retry_count >= 0),
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    process_time TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_event_queue_subscription ON event_queue(subscription_id);
CREATE INDEX idx_event_queue_status ON event_queue(status);
CREATE INDEX idx_event_queue_create_time ON event_queue(create_time);
CREATE INDEX idx_event_queue_pending ON event_queue(status, retry_count) WHERE status = 0;

-- =============================================================================
-- Event Log (Журнал событий)
-- =============================================================================
CREATE TABLE IF NOT EXISTS event_log (
    id SERIAL PRIMARY KEY,
    event_type INT NOT NULL,
    object_type INT DEFAULT 0,
    object_id INT DEFAULT 0,
    user_id INT DEFAULT 0,
    event_data JSONB,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    flags INT DEFAULT 0
);

CREATE INDEX idx_event_log_type ON event_log(event_type);
CREATE INDEX idx_event_log_object ON event_log(object_type, object_id);
CREATE INDEX idx_event_log_time ON event_log(event_time);
CREATE INDEX idx_event_log_user ON event_log(user_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_event_subscription_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_event_subscription_update
    BEFORE UPDATE ON event_subscription
    FOR EACH ROW
    EXECUTE FUNCTION update_event_subscription_timestamp();

CREATE OR REPLACE FUNCTION update_event_queue_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_event_queue_update
    BEFORE UPDATE ON event_queue
    FOR EACH ROW
    EXECUTE FUNCTION update_event_queue_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Получить активные подписки для события
CREATE OR REPLACE FUNCTION get_active_subscriptions(p_event_type INT, p_object_type INT DEFAULT 0, p_object_id INT DEFAULT 0)
RETURNS TABLE (
    id INT,
    name TEXT,
    user_id INT,
    config JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        es.id,
        es.name,
        es.user_id,
        es.config
    FROM event_subscription es
    WHERE es.event_type = p_event_type
      AND (es.object_type = 0 OR es.object_type = p_object_type)
      AND (es.object_id = 0 OR es.object_id = p_object_id)
      AND es.start_date <= NOW() 
      AND es.end_date >= NOW()
      AND (es.flags & 1) = 0;
END;
$$ LANGUAGE plpgsql;

-- Добавить событие в очередь
CREATE OR REPLACE FUNCTION queue_event(p_subscription_id INT, p_event_type INT, p_object_type INT, p_object_id INT, p_event_data JSONB DEFAULT NULL)
RETURNS INT AS $$
DECLARE
    v_queue_id INT;
BEGIN
    INSERT INTO event_queue (subscription_id, event_type, object_type, object_id, event_data, status)
    VALUES (p_subscription_id, p_event_type, p_object_type, p_object_id, p_event_data, 0)
    RETURNING id INTO v_queue_id;
    
    RETURN v_queue_id;
END;
$$ LANGUAGE plpgsql;

-- Обработать событие (пометить как обработанное)
CREATE OR REPLACE FUNCTION complete_event(p_queue_id INT, p_success BOOLEAN DEFAULT TRUE, p_error_message TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    UPDATE event_queue
    SET status = CASE WHEN p_success THEN 2 ELSE 3 END,
        process_time = CURRENT_TIMESTAMP,
        error_message = p_error_message,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_queue_id;
END;
$$ LANGUAGE plpgsql;

-- Повторить неудачное событие
CREATE OR REPLACE FUNCTION retry_event(p_queue_id INT)
RETURNS VOID AS $$
BEGIN
    UPDATE event_queue
    SET status = 0,
        retry_count = retry_count + 1,
        process_time = NULL,
        error_message = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_queue_id AND status = 3 AND retry_count < 5;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Статистика событий по типам
CREATE OR REPLACE VIEW v_event_type_stats AS
SELECT 
    event_type,
    COUNT(*) AS total_events,
    COUNT(CASE WHEN status = 2 THEN 1 END) AS completed,
    COUNT(CASE WHEN status = 3 THEN 1 END) AS failed,
    MIN(create_time) AS first_event,
    MAX(create_time) AS last_event
FROM event_queue
GROUP BY event_type;

-- Подписки пользователей
CREATE OR REPLACE VIEW v_user_subscriptions AS
SELECT 
    u.id AS user_id,
    u.name AS user_name,
    COUNT(es.id) AS subscription_count,
    COUNT(CASE WHEN es.start_date <= NOW() AND es.end_date >= NOW() AND (es.flags & 1) = 0 THEN 1 END) AS active_count
FROM usr u
LEFT JOIN event_subscription es ON es.user_id = u.id
GROUP BY u.id, u.name;
