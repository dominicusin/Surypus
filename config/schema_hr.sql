-- ============================================================
-- HR Tables - Управление персоналом
-- Соответствует C++ objstaff.cpp
-- ============================================================

-- Departments (подразделения)
CREATE TABLE IF NOT EXISTS department (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES department(id),
    manager_id BIGINT REFERENCES person(id),
    head_id BIGINT REFERENCES person(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Positions (должности)
CREATE TABLE IF NOT EXISTS position (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    department_id BIGINT REFERENCES department(id),
    salary_min NUMERIC(18,2),
    salary_max NUMERIC(18,2),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employees (сотрудники)
CREATE TABLE IF NOT EXISTS employee (
    id BIGSERIAL PRIMARY KEY,
    tab_no VARCHAR(16) NOT NULL,
    person_id BIGINT NOT NULL REFERENCES person(id),
    department_id BIGINT REFERENCES department(id),
    position_id BIGINT NOT NULL REFERENCES position(id),
    hire_date DATE NOT NULL,
    fire_date DATE,
    status SMALLINT DEFAULT 0,  -- 0=WORKING, 1=VACATION, 2=SICK, 3=MATERNITY, 4=FIRE, 5=DISMISSED
    salary NUMERIC(18,2) NOT NULL DEFAULT 0,
    rate NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tab_no)
);

-- Employee history (история приёмов/увольнений)
CREATE TABLE IF NOT EXISTS employee_history (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id),
    dt DATE NOT NULL,
    action SMALLINT NOT NULL,  -- 0=HIRE, 1=FIRE, 2=TRANSFER, 3=SALARY_CHANGE
    old_value TEXT,
    new_value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для HR
CREATE INDEX IF NOT EXISTS idx_employee_tabno ON employee(tab_no);
CREATE INDEX IF NOT EXISTS idx_employee_person ON employee(person_id);
CREATE INDEX IF NOT EXISTS idx_employee_department ON employee(department_id);
CREATE INDEX IF NOT EXISTS idx_employee_position ON employee(position_id);
CREATE INDEX IF NOT EXISTS idx_employee_status ON employee(status);

CREATE INDEX IF NOT EXISTS idx_department_parent ON department(parent_id);

CREATE INDEX IF NOT EXISTS idx_position_department ON position(department_id);

-- ============================================================
-- Функции для HR
-- ============================================================

-- Расчёт зарплаты с учётом ставки
CREATE OR REPLACE FUNCTION calc_emp_salary(p_salary NUMERIC(18,2), p_rate NUMERIC(5,2))
RETURNS NUMERIC(18,2) AS $$
BEGIN
    RETURN p_salary * p_rate;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Приём сотрудника
CREATE OR REPLACE FUNCTION hire_employee(
    p_tab_no VARCHAR(16),
    p_person_id BIGINT,
    p_position_id BIGINT,
    p_hire_date DATE,
    p_salary NUMERIC(18,2),
    p_rate NUMERIC(5,2)
) RETURNS BIGINT AS $$
DECLARE
    v_emp_id BIGINT;
BEGIN
    INSERT INTO employee (tab_no, person_id, position_id, hire_date, salary, rate, status)
    VALUES (p_tab_no, p_person_id, p_position_id, p_hire_date, p_salary, p_rate, 0)
    RETURNING id INTO v_emp_id;
    
    -- Записать историю
    INSERT INTO employee_history (employee_id, dt, action, new_value)
    VALUES (v_emp_id, p_hire_date, 0, p_salary::TEXT);
    
    RETURN v_emp_id;
END;
$$ LANGUAGE plpgsql;

-- Увольнение сотрудника
CREATE OR REPLACE FUNCTION fire_employee(p_emp_id BIGINT, p_fire_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE employee 
    SET fire_date = p_fire_date, status = 4, updated_at = NOW()
    WHERE id = p_emp_id AND status = 0;
    
    INSERT INTO employee_history (employee_id, dt, action)
    VALUES (p_emp_id, p_fire_date, 1);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Перевод сотрудника
CREATE OR REPLACE FUNCTION transfer_employee(
    p_emp_id BIGINT,
    p_department_id BIGINT,
    p_position_id BIGINT,
    p_dt DATE
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE employee 
    SET department_id = p_department_id, position_id = p_position_id, updated_at = NOW()
    WHERE id = p_emp_id;
    
    INSERT INTO employee_history (employee_id, dt, action, new_value)
    VALUES (p_emp_id, p_dt, 2, 'dept=' || p_department_id || ', pos=' || p_position_id);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Штатное расписание
CREATE OR REPLACE VIEW v_staff_list AS
SELECT 
    e.id, e.tab_no, p.name AS person_name,
    d.name AS department_name, pos.name AS position_name,
    e.hire_date, e.fire_date, e.status,
    e.salary, e.rate, e.salary * e.rate AS calc_salary
FROM employee e
JOIN person p ON p.id = e.person_id
LEFT JOIN department d ON d.id = e.department_id
JOIN position pos ON pos.id = e.position_id
WHERE e.status != 5  -- Не уволенные по инициативе работодателя
ORDER BY d.name, pos.name, p.name;

-- Сотрудники в подразделении
CREATE OR REPLACE VIEW v_department_staff AS
SELECT 
    d.id AS department_id, d.name AS department_name,
    e.id AS employee_id, p.name AS employee_name,
    pos.name AS position_name, e.status
FROM department d
LEFT JOIN employee e ON e.department_id = d.id AND e.status = 0
JOIN person p ON p.id = e.person_id
JOIN position pos ON pos.id = e.position_id
ORDER BY d.name, p.name;

-- Фонд заработной платы по подразделениям
CREATE OR REPLACE VIEW v_salary_fund AS
SELECT 
    d.id AS department_id, d.name AS department_name,
    COUNT(e.id) AS employee_count,
    SUM(e.salary * e.rate) AS total_salary_fund,
    AVG(e.salary * e.rate) AS avg_salary
FROM department d
LEFT JOIN employee e ON e.department_id = d.id AND e.status = 0
GROUP BY d.id, d.name
ORDER BY d.name;

-- История изменений
CREATE TABLE IF NOT EXISTS v_employee_history AS
SELECT 
    eh.id, eh.employee_id, e.tab_no, p.name AS person_name,
    eh.dt, eh.action,
    CASE eh.action 
        WHEN 0 THEN 'Приём'
        WHEN 1 THEN 'Увольнение'
        WHEN 2 THEN 'Перевод'
        WHEN 3 THEN 'Изменение оклада'
    END AS action_name,
    eh.old_value, eh.new_value
FROM employee_history eh
JOIN employee e ON e.id = eh.employee_id
JOIN person p ON p.id = e.person_id
ORDER BY eh.dt DESC;
