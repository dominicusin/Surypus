-- ============================================================
-- Event Tables - События
-- ============================================================

-- Events (события)
CREATE TABLE IF NOT EXISTS event (
    id BIGSERIAL PRIMARY KEY,
    etype SMALLINT NOT NULL,  -- 0=CREATED, 1=MODIFIED, 2=DELETED, 3=STATUS_CHANGED, 4=APPROVED, 5=REJECTED, 6=COMMENTED, 7=NOTIFIED
    object_type SMALLINT NOT NULL,  -- 0=BILL, 1=ORDER, 2=GOODS, 3=CONTRACT, 4=TASK, 5=PROJECT
    object_id BIGINT NOT NULL,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    priority SMALLINT DEFAULT 3,  -- 0-5
    subject VARCHAR(256) NOT NULL,
    body TEXT,
    author_id BIGINT NOT NULL REFERENCES person(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_event_object ON event(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_event_date ON event(dt);
CREATE INDEX IF NOT idx_event_author ON event(author_id);

-- ============================================================
-- Функции
-- ============================================================

-- Записать событие
CREATE OR REPLACE FUNCTION record_event(
    p_etype SMALLINT,
    p_object_type SMALLINT,
    p_object_id BIGINT,
    p_priority SMALLINT,
    p_subject VARCHAR,
    p_body TEXT,
    p_author_id BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO event (etype, object_type, object_id, priority, subject, body, author_id)
    VALUES (p_etype, p_object_type, p_object_id, p_priority, p_subject, p_body, p_author_id)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Получить события объекта
CREATE OR REPLACE FUNCTION get_object_events(
    p_object_type SMALLINT,
    p_object_id BIGINT,
    p_limit INT DEFAULT 100
) RETURNS SETOF event AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM event
    WHERE object_type = p_object_type AND object_id = p_object_id
    ORDER BY dt DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- История событий документа
CREATE VIEW v_bill_events AS
SELECT e.*, p.name AS author_name
FROM event e
LEFT JOIN person p ON p.id = e.author_id
WHERE e.object_type = 0
ORDER BY e.dt DESC;

-- События за период
CREATE VIEW v_events_period AS
SELECT e.id, e.etype, e.object_type, e.object_id, e.dt, e.priority, e.subject, e.author_id, p.name AS author_name
FROM event e
LEFT JOIN person p ON p.id = e.author_id
WHERE e.dt >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY e.dt DESC;
