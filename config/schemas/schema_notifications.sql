-- ============================================================
-- Notifications Tables - Уведомления и задачи
-- ============================================================

-- Notification types (типы уведомлений)
CREATE TABLE IF NOT EXISTS notification_type (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    code VARCHAR(32) NOT NULL,
    priority SMALLINT DEFAULT 3,  -- 1=низкий, 5=высокий
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Notifications (уведомления)
CREATE TABLE IF NOT EXISTS notification (
    id BIGSERIAL PRIMARY KEY,
    ntype SMALLINT NOT NULL REFERENCES notification_type(id),
    priority SMALLINT DEFAULT 3,
    sender_id BIGINT REFERENCES person(id),
    recipient_id BIGINT NOT NULL REFERENCES person(id),
    subject VARCHAR(256) NOT NULL,
    body TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=PENDING, 2=SENT, 3=DELIVERED, 4=READ, 5=ARCHIVED, 6=DELETED
    flags INTEGER DEFAULT 0
);

-- Tasks (задачи)
CREATE TABLE IF NOT EXISTS task (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(256) NOT NULL,
    description TEXT,
    creator_id BIGINT NOT NULL REFERENCES person(id),
    assignee_id BIGINT NOT NULL REFERENCES person(id),
    priority SMALLINT DEFAULT 2,  -- 0=LOW, 1=NORMAL, 2=HIGH, 3=URGENT
    status SMALLINT DEFAULT 0,  -- 0=OPEN, 1=INPROGRESS, 2=PENDING, 3=COMPLETED, 4=CANCELLED
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    flags INTEGER DEFAULT 0
);

-- Task comments (комментарии к задачам)
CREATE TABLE IF NOT EXISTS task_comment (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES task(id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES person(id),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Task attachments (вложения)
CREATE TABLE IF NOT EXISTS task_attachment (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES task(id) ON DELETE CASCADE,
    filename VARCHAR(256) NOT NULL,
    file_path VARCHAR(512),
    file_size BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для уведомлений и задач
CREATE INDEX IF NOT EXISTS idx_notification_recipient ON notification(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notification_status ON notification(status);
CREATE INDEX IF NOT EXISTS idx_notification_created ON notification(created_at);

CREATE INDEX IF NOT EXISTS idx_task_assignee ON task(assignee_id);
CREATE INDEX IF NOT EXISTS idx_task_status ON task(status);
CREATE INDEX IF NOT EXISTS idx_task_due ON task(due_date);

CREATE INDEX IF NOT EXISTS idx_task_comment_task ON task_comment(task_id);

-- ============================================================
-- Функции для уведомлений и задач
-- ============================================================

-- Создать уведомление
CREATE OR REPLACE FUNCTION create_notification(
    p_ntype SMALLINT,
    p_priority SMALLINT,
    p_recipient_id BIGINT,
    p_subject VARCHAR(256),
    p_body TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO notification (ntype, priority, recipient_id, subject, body, status)
    VALUES (p_ntype, p_priority, p_recipient_id, p_subject, p_body, 1)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Отправить уведомление
CREATE OR REPLACE FUNCTION send_notification(p_notif_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification 
    SET status = 2, sent_at = NOW()
    WHERE id = p_notif_id AND status = 1;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Прочитать уведомление
CREATE OR REPLACE FUNCTION read_notification(p_notif_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification 
    SET status = 4, read_at = NOW()
    WHERE id = p_notif_id AND status IN (2, 3);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Создать задачу
CREATE OR REPLACE FUNCTION create_task(
    p_title VARCHAR(256),
    p_description TEXT,
    p_creator_id BIGINT,
    p_assignee_id BIGINT,
    p_priority SMALLINT,
    p_due_date DATE
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO task (title, description, creator_id, assignee_id, priority, due_date, status)
    VALUES (p_title, p_description, p_creator_id, p_assignee_id, p_priority, p_due_date, 0)
    RETURNING id INTO v_id;
    
    -- Создать уведомление для исполнителя
    PERFORM create_notification(2, p_priority, p_assignee_id, 'Новая задача: ' || p_title, p_description);
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Завершить задачу
CREATE OR REPLACE FUNCTION complete_task(p_task_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE task 
    SET status = 3, completed_at = NOW()
    WHERE id = p_task_id AND status IN (0, 1, 2);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Непрочитанные уведомления
CREATE OR REPLACE VIEW v_unread_notifications AS
SELECT 
    n.id, n.subject, n.body, n.created_at, n.priority,
    p.name AS recipient_name,
    nt.name AS type_name
FROM notification n
JOIN person p ON p.id = n.recipient_id
JOIN notification_type nt ON nt.id = n.ntype
WHERE n.status IN (1, 2, 3)  -- PENDING, SENT, DELIVERED
ORDER BY n.priority DESC, n.created_at DESC;

-- Активные задачи
CREATE OR REPLACE VIEW v_active_tasks AS
SELECT 
    t.id, t.title, t.description, t.priority, t.status, t.due_date, t.created_at,
    pc.name AS creator_name,
    pa.name AS assignee_name,
    CASE t.priority 
        WHEN 0 THEN 'Низкий'
        WHEN 1 THEN 'Обычный'
        WHEN 2 THEN 'Высокий'
        WHEN 3 THEN 'Срочный'
    END AS priority_name,
    CASE t.status
        WHEN 0 THEN 'Открыта'
        WHEN 1 THEN 'В работе'
        WHEN 2 THEN 'Ожидает'
        WHEN 3 THEN 'Завершена'
        WHEN 4 THEN 'Отменена'
    END AS status_name
FROM task t
JOIN person pc ON pc.id = t.creator_id
JOIN person pa ON pa.id = t.assignee_id
WHERE t.status IN (0, 1, 2)  -- OPEN, INPROGRESS, PENDING
ORDER BY t.priority DESC, t.due_date;

-- Просроченные задачи
CREATE OR REPLACE VIEW v_overdue_tasks AS
SELECT 
    t.id, t.title, t.description, t.due_date, t.priority,
    p.name AS assignee_name,
    CURRENT_DATE - t.due_date AS days_overdue
FROM task t
JOIN person p ON p.id = t.assignee_id
WHERE t.due_date < CURRENT_DATE 
    AND t.status IN (0, 1, 2)
ORDER BY t.due_date;

-- Мои задачи
CREATE OR REPLACE VIEW v_my_tasks AS
SELECT 
    t.id, t.title, t.status, t.due_date, t.priority,
    pc.name AS creator_name,
    t.created_at
FROM task t
JOIN person pc ON pc.id = t.creator_id
WHERE t.assignee_id = current_user  -- requires session context
ORDER BY t.due_date, t.priority DESC;

-- Статистика задач
CREATE OR REPLACE VIEW v_task_stats AS
SELECT 
    assignee_id,
    p.name AS assignee_name,
    COUNT(*) AS total_tasks,
    COUNT(CASE WHEN status = 0 THEN 1 END) AS open_count,
    COUNT(CASE WHEN status = 1 THEN 1 END) AS inprogress_count,
    COUNT(CASE WHEN status = 2 THEN 1 END) AS pending_count,
    COUNT(CASE WHEN status = 3 THEN 1 END) AS completed_count,
    COUNT(CASE WHEN status = 4 THEN 1 END) AS cancelled_count,
    COUNT(CASE WHEN due_date < CURRENT_DATE AND status IN (0, 1, 2) THEN 1 END) AS overdue_count
FROM task t
JOIN person p ON p.id = t.assignee_id
GROUP BY assignee_id, p.name
ORDER BY p.name;
