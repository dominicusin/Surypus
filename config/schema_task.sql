-- =================================================================
-- Task System - Задачи и напоминания
-- =================================================================
-- Analog: OpenPapyrus pplib/ppjob.cpp (PPObjTask)

-- Task (задачи)
CREATE TABLE IF NOT EXISTS task (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(256) NOT NULL,
    description TEXT,
    owner_id BIGINT NOT NULL,           -- Создатель
    assignee_id BIGINT NOT NULL,        -- Исполнитель
    parent_id BIGINT REFERENCES task(id), -- Родительская задача
    object_type BIGINT,                 -- PPOBJ_XXX связанного объекта
    object_id BIGINT,                   -- ID связанного объекта
    due_date DATE,
    priority SMALLINT NOT NULL DEFAULT 1, -- 0=Low, 1=Normal, 2=High, 3=Critical
    status SMALLINT NOT NULL DEFAULT 0,   -- 0=Draft, 1=Active, 2=InProgress, 3=Completed, 4=Canceled, 5=Rejected
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_assignee ON task(assignee_id);
CREATE INDEX IF NOT EXISTS idx_task_owner ON task(owner_id);
CREATE INDEX IF NOT EXISTS idx_task_status ON task(status);
CREATE INDEX IF NOT EXISTS idx_task_due_date ON task(due_date);
CREATE INDEX IF NOT EXISTS idx_task_priority ON task(priority);
CREATE INDEX IF NOT EXISTS idx_task_object ON task(object_type, object_id);

-- Task Comment (комментарии)
CREATE TABLE IF NOT EXISTS task_comment (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES task(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL,
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_comment_task ON task_comment(task_id);
CREATE INDEX IF NOT EXISTS idx_task_comment_user ON task_comment(user_id);

-- Task Attachment (вложения)
CREATE TABLE IF NOT EXISTS task_attachment (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES task(id) ON DELETE CASCADE,
    file_name VARCHAR(256) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_attachment_task ON task_attachment(task_id);

-- =================================================================
-- Functions
-- =================================================================

-- Create task
CREATE OR REPLACE FUNCTION create_task(BIGINT, BIGINT, TEXT, DATE, SMALLINT)
RETURNS BIGINT AS $$
DECLARE
    p_owner_id ALIAS FOR $1;
    p_assignee_id ALIAS FOR $2;
    p_title ALIAS FOR $3;
    p_due_date ALIAS FOR $4;
    p_priority ALIAS FOR $5;
    v_task_id BIGINT;
BEGIN
    INSERT INTO task (title, owner_id, assignee_id, due_date, priority, status)
    VALUES (p_title, p_owner_id, p_assignee_id, p_due_date, p_priority, 1)  -- Active
    RETURNING id INTO v_task_id;
    
    RETURN v_task_id;
END;
$$ LANGUAGE plpgsql;

-- Complete task
CREATE OR REPLACE FUNCTION complete_task(BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    p_task_id ALIAS FOR $1;
    v_status SMALLINT;
BEGIN
    SELECT status INTO v_status FROM task WHERE id = p_task_id;
    
    IF v_status NOT IN (1, 2) THEN  -- Not Active or InProgress
        RETURN FALSE;
    END IF;
    
    UPDATE task 
    SET status = 3, completed_at = NOW(), updated_at = NOW()
    WHERE id = p_task_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Get user tasks
CREATE OR REPLACE FUNCTION get_user_tasks(BIGINT, SMALLINT)
RETURNS TABLE (id BIGINT, title TEXT, description TEXT, due_date DATE,
               priority SMALLINT, status SMALLINT, created_at TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.title, t.description, t.due_date, t.priority, t.status, t.created_at
    FROM task t
    WHERE t.assignee_id = $1 
      AND t.status IN (1, 2)  -- Active, InProgress
      AND ($2 IS NULL OR t.priority >= $2)
    ORDER BY t.priority DESC, t.due_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get overdue tasks
CREATE OR REPLACE FUNCTION get_overdue_tasks(BIGINT)
RETURNS TABLE (id BIGINT, title TEXT, assignee_id BIGINT, due_date DATE, priority SMALLINT) AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.title, t.assignee_id, t.due_date, t.priority
    FROM task t
    WHERE t.status IN (1, 2)  -- Active, InProgress
      AND t.due_date < CURRENT_DATE
      AND ($1 IS NULL OR t.assignee_id = $1)
    ORDER BY t.due_date, t.priority DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Add comment
CREATE OR REPLACE FUNCTION add_task_comment(BIGINT, BIGINT, TEXT)
RETURNS BIGINT AS $$
DECLARE
    p_task_id ALIAS FOR $1;
    p_user_id ALIAS FOR $2;
    p_text ALIAS FOR $3;
    v_comment_id BIGINT;
BEGIN
    INSERT INTO task_comment (task_id, user_id, text)
    VALUES (p_task_id, p_user_id, p_text)
    RETURNING id INTO v_comment_id;
    
    RETURN v_comment_id;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_task_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_task_update
    BEFORE UPDATE ON task
    FOR EACH ROW EXECUTE FUNCTION update_task_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE task IS 'Задачи (аналог TaskTbl)';
COMMENT ON TABLE task_comment IS 'Комментарии к задачам';
COMMENT ON TABLE task_attachment IS 'Вложения задач';
COMMENT ON task.priority IS 'Приоритет: 0=Низкий, 1=Обычный, 2=Высокий, 3=Критический';
COMMENT ON task.status IS 'Статус: 0=Черновик, 1=Активна, 2=В работе, 3=Выполнена, 4=Отменена, 5=Отклонена';
