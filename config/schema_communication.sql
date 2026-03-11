-- ============================================================
-- Communication Tables - Коммуникации
-- ============================================================

-- Messages (сообщения)
CREATE TABLE IF NOT EXISTS message (
    id BIGSERIAL PRIMARY KEY,
    mtype SMALLINT NOT NULL,  -- 0=NOTIFICATION, 1=INVOICE, 2=ORDER, 3=REMINDER, 4=ALERT, 5=MARKETING
    channel SMALLINT NOT NULL,  -- 0=EMAIL, 1=SMS, 2=PUSH, 3=TELEGRAM
    msg_from VARCHAR(256) NOT NULL,
    msg_to VARCHAR(256) NOT NULL,
    msg_cc VARCHAR(512),
    subject VARCHAR(512) NOT NULL,
    body TEXT NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=QUEUED, 2=SENDING, 3=SENT, 4=DELIVERED, 5=READ, 6=FAILED
    priority SMALLINT DEFAULT 1,  -- 0-3
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email accounts (учётные записи email)
CREATE TABLE IF NOT EXISTS email_account (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(256) NOT NULL,
    smtp_host VARCHAR(256),
    smtp_port INT DEFAULT 587,
    username VARCHAR(256),
    password_hash VARCHAR(256),
    use_tls BOOLEAN DEFAULT TRUE,
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=INACTIVE
    flags INTEGER DEFAULT 0,
    UNIQUE(email)
);

-- SMS providers (SMS провайдеры)
CREATE TABLE IF NOT EXISTS sms_provider (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    api_url VARCHAR(512),
    api_key VARCHAR(256),
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(name)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_message_status ON message(status);
CREATE INDEX IF NOT EXISTS idx_message_channel ON message(channel);
CREATE INDEX IF NOT EXISTS idx_message_to ON message(msg_to);
CREATE INDEX IF NOT EXISTS idx_message_dates ON message(created_at, sent_at);

-- ============================================================
-- Функции
-- ============================================================

-- Создать сообщение
CREATE OR REPLACE FUNCTION create_message(
    p_mtype SMALLINT,
    p_channel SMALLINT,
    p_from VARCHAR,
    p_to VARCHAR,
    p_subject VARCHAR,
    p_body TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO message (mtype, channel, msg_from, msg_to, subject, body, status)
    VALUES (p_mtype, p_channel, p_from, p_to, p_subject, p_body, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Отправить сообщение
CREATE OR REPLACE FUNCTION send_message(p_message_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE message 
    SET status = 3, sent_at = NOW() 
    WHERE id = p_message_id AND status = 1;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Записать доставку
CREATE OR REPLACE FUNCTION deliver_message(p_message_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE message 
    SET status = 4, delivered_at = NOW() 
    WHERE id = p_message_id AND status = 3;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Записать прочтение
CREATE OR REPLACE FUNCTION read_message(p_message_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE message 
    SET status = 5, read_at = NOW() 
    WHERE id = p_message_id AND status IN (3, 4);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Очередь сообщений
CREATE VIEW v_message_queue AS
SELECT 
    m.id, m.mtype, m.channel, m.msg_to, m.subject, m.priority, m.created_at,
    CASE m.channel
        WHEN 0 THEN 'Email'
        WHEN 1 THEN 'SMS'
        WHEN 2 THEN 'Push'
        WHEN 3 THEN 'Telegram'
    END AS channel_name,
    CASE m.status
        WHEN 0 THEN 'Черновик'
        WHEN 1 THEN 'В очереди'
        WHEN 2 THEN 'Отправляется'
        WHEN 3 THEN 'Отправлено'
        WHEN 4 THEN 'Доставлено'
        WHEN 5 THEN 'Прочитано'
        WHEN 6 THEN 'Ошибка'
    END AS status_name
FROM message m
WHERE m.status IN (1, 2)  -- QUEUED, SENDING
ORDER BY m.priority DESC, m.created_at;

-- Статистика сообщений
CREATE VIEW v_message_stats AS
SELECT 
    m.channel,
    COUNT(*) AS total,
    COUNT(CASE WHEN m.status = 3 THEN 1 END) AS sent,
    COUNT(CASE WHEN m.status = 4 THEN 1 END) AS delivered,
    COUNT(CASE WHEN m.status = 5 THEN 1 END) AS read,
    COUNT(CASE WHEN m.status = 6 THEN 1 END) AS failed
FROM message m
WHERE m.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY m.channel;
