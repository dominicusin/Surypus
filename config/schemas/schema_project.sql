-- =============================================================================
-- ПРОЕКТЫ
-- Соответствуют Core.Project.Project
-- Аналог: PPOBJ_PROJECT
-- =============================================================================

CREATE TABLE IF NOT EXISTS project (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    client_id INT DEFAULT 0,
    manager_id INT DEFAULT 0,
    start_date DATE NOT NULL,
    end_date DATE,
    budget NUMERIC(18,4) DEFAULT 0 CHECK (budget >= 0),
    status INT DEFAULT 0,  -- 0:Draft, 1:Active, 2:OnHold, 3:Completed, 4:Cancelled
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_project_client ON project(client_id);
CREATE INDEX idx_project_manager ON project(manager_id);
CREATE INDEX idx_project_status ON project(status);

CREATE TABLE IF NOT EXISTS prj_task (
    id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
    parent_id INT DEFAULT 0,
    name VARCHAR(256) NOT NULL,
    assignee_id INT DEFAULT 0,
    start_date DATE NOT NULL,
    due_date DATE,
    complete_pct INT DEFAULT 0 CHECK (complete_pct >= 0 AND complete_pct <= 100),
    status INT DEFAULT 0,  -- 0:Todo, 1:InProgress, 2:Review, 3:Done, 4:Blocked
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prj_task_project ON prj_task(project_id);
CREATE INDEX idx_prj_task_parent ON prj_task(parent_id);
CREATE INDEX idx_prj_task_assignee ON prj_task(assignee_id);
CREATE INDEX idx_prj_task_status ON prj_task(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_project_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_project_update
    BEFORE UPDATE ON project
    FOR EACH ROW
    EXECUTE FUNCTION update_project_timestamp();

CREATE TRIGGER trigger_prj_task_update
    BEFORE UPDATE ON prj_task
    FOR EACH ROW
    EXECUTE FUNCTION update_project_timestamp();

-- VIEW: Задачи по проектам
CREATE OR REPLACE VIEW v_project_tasks AS
SELECT 
    p.id AS project_id,
    p.name AS project_name,
    p.code AS project_code,
    pt.id AS task_id,
    pt.name AS task_name,
    pt.parent_id,
    pt.assignee_id,
    a.name AS assignee_name,
    pt.start_date,
    pt.due_date,
    pt.complete_pct,
    pt.status,
    CASE pt.status
        WHEN 0 THEN 'Todo'
        WHEN 1 THEN 'In Progress'
        WHEN 2 THEN 'Review'
        WHEN 3 THEN 'Done'
        WHEN 4 THEN 'Blocked'
    END AS status_text
FROM project p
JOIN prj_task pt ON pt.project_id = p.id
LEFT JOIN person a ON a.id = pt.assignee_id
ORDER BY p.name, pt.parent_id, pt.id;
