-- ============================================================
-- Additional Tables - HR, Analytics, Notifications
-- Add to existing schema
-- ============================================================

-- ============================================================
-- HR Tables - Кадры
-- ============================================================

-- Departments
CREATE TABLE IF NOT EXISTS department (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES department(id),
    manager_id BIGINT,
    head_count INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Positions
CREATE TABLE IF NOT EXISTS position (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    department_id BIGINT REFERENCES department(id),
    salary_min NUMERIC(18,4),
    salary_max NUMERIC(18,4),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employees
CREATE TABLE IF NOT EXISTS employee (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    department_id BIGINT REFERENCES department(id),
    position_id BIGINT REFERENCES position(id),
    hire_date DATE NOT NULL,
    fire_date DATE,
    salary NUMERIC(18,4),
    tab_no VARCHAR(16),
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_employee_person ON employee(person_id);
CREATE INDEX IF NOT EXISTS idx_employee_department ON employee(department_id);
CREATE INDEX IF NOT EXISTS idx_employee_status ON employee(status);

-- Time sheets
CREATE TABLE IF NOT EXISTS time_sheet (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    month INTEGER NOT NULL,
    year INTEGER NOT NULL,
    total_hours NUMERIC(6,2) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, month, year)
);

-- Time entries
CREATE TABLE IF NOT EXISTS time_entry (
    id BIGSERIAL PRIMARY KEY,
    time_sheet_id BIGINT NOT NULL REFERENCES time_sheet(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    hours NUMERIC(4,2) NOT NULL,
    work_type SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(time_sheet_id, date)
);

-- Vacations
CREATE TABLE IF NOT EXISTS vacation (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    type SMALLINT NOT NULL,
    days INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vacation_employee ON vacation(employee_id);

-- Sick leaves
CREATE TABLE IF NOT EXISTS sick_leave (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days INTEGER NOT NULL,
    percent NUMERIC(5,2) DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Salary
CREATE TABLE IF NOT EXISTS salary (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    dt DATE NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    salary_type SMALLINT DEFAULT 0,
    hours NUMERIC(6,2),
    tax NUMERIC(18,4) DEFAULT 0,
    net NUMERIC(18,4) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_salary_employee ON salary(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_dt ON salary(dt);

-- ============================================================
-- Analytics Tables - Аналитика
-- ============================================================

-- Report templates
CREATE TABLE IF NOT EXISTS report_template (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    category SMALLINT NOT NULL,
    query TEXT NOT NULL,
    params JSONB,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dashboards
CREATE TABLE IF NOT EXISTS dashboard (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    owner_id BIGINT NOT NULL REFERENCES users(id),
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Widgets
CREATE TABLE IF NOT EXISTS widget (
    id BIGSERIAL PRIMARY KEY,
    dashboard_id BIGINT NOT NULL REFERENCES dashboard(id) ON DELETE CASCADE,
    widget_type SMALLINT NOT NULL,
    title VARCHAR(256),
    config JSONB,
    pos_x INTEGER DEFAULT 0,
    pos_y INTEGER DEFAULT 0,
    width INTEGER DEFAULT 4,
    height INTEGER DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- KPIs
CREATE TABLE IF NOT EXISTS kpi (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    value NUMERIC(18,4),
    target NUMERIC(18,4),
    unit VARCHAR(16),
    trend SMALLINT DEFAULT 0,
    status SMALLINT DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Notifications Tables - Уведомления
-- ============================================================

-- Notifications
CREATE TABLE IF NOT EXISTS notification (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    type SMALLINT NOT NULL,
    title VARCHAR(256) NOT NULL,
    message TEXT,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE,
    action_url VARCHAR(512),
    data JSONB
);

CREATE INDEX IF NOT EXISTS idx_notification_user ON notification(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_read ON notification(user_id, is_read);

-- Events
CREATE TABLE IF NOT EXISTS event (
    id BIGSERIAL PRIMARY KEY,
    event_type SMALLINT NOT NULL,
    obj_type BIGINT,
    obj_id BIGINT,
    user_id BIGINT REFERENCES users(id),
    data JSONB,
    dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_event_obj ON event(obj_type, obj_id);
CREATE INDEX IF NOT EXISTS idx_event_dt ON event(dt);

-- Tasks
CREATE TABLE IF NOT EXISTS task (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(256) NOT NULL,
    description TEXT,
    owner_id BIGINT NOT NULL REFERENCES users(id),
    assignee_id BIGINT NOT NULL REFERENCES users(id),
    due_date DATE,
    priority SMALLINT DEFAULT 1,
    status SMALLINT DEFAULT 0,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_task_assignee ON task(assignee_id, status);
CREATE INDEX IF NOT EXISTS idx_task_due ON task(due_date);

-- Reminders
CREATE TABLE IF NOT EXISTS reminder (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    dt DATE NOT NULL,
    title VARCHAR(256) NOT NULL,
    obj_type BIGINT,
    obj_id BIGINT,
    repeat_expr VARCHAR(32),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reminder_user_dt ON reminder(user_id, dt);

-- Alerts
CREATE TABLE IF NOT EXISTS alert (
    id BIGSERIAL PRIMARY KEY,
    alert_type VARCHAR(32) NOT NULL,
    title VARCHAR(256) NOT NULL,
    message TEXT,
    severity SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_dismissed BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_alert_dismissed ON alert(is_dismissed);

-- Subscriptions
CREATE TABLE IF NOT EXISTS subscription (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    event_type SMALLINT NOT NULL,
    obj_type BIGINT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, event_type, obj_type)
);

-- ============================================================
-- Insert default data
-- ============================================================

-- Default departments
INSERT INTO department (name) VALUES
    ('Администрация'),
    ('Бухгалтерия'),
    ('Отдел продаж'),
    ('Склад'),
    ('Касса')
ON CONFLICT DO NOTHING;

-- Default positions
INSERT INTO position (name, salary_min, salary_max) VALUES
    ('Директор', 100000, 200000),
    ('Бухгалтер', 50000, 100000),
    ('Менеджер', 40000, 80000),
    ('Кассир', 35000, 60000),
    ('Кладовщик', 35000, 60000)
ON CONFLICT DO NOTHING;

-- Default KPIs
INSERT INTO kpi (name, description, value, target, unit, status) VALUES
    ('Продажи за месяц', 'Общая сумма продаж', 0, 1000000, '₽', 1),
    ('Количество чеков', 'Количество транзакций', 0, 1000, 'шт', 1),
    ('Средний чек', 'Средняя сумма чека', 0, 5000, '₽', 1),
    ('Товары без движения', 'Товары без продаж > 90 дней', 0, 10, 'шт', 1),
    ('Дебиторская задолженность', 'Сумма дебиторки', 0, 500000, '₽', 1)
ON CONFLICT DO NOTHING;
