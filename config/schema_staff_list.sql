-- =============================================================================
-- ШТАТНОЕ РАСПИСАНИЕ
-- Соответствуют Core.HR.StaffList
-- Аналог: PPOBJ_STAFFLIST2
-- =============================================================================

CREATE TABLE IF NOT EXISTS staff_list (
    id SERIAL PRIMARY KEY,
    position_id INT NOT NULL,
    dept_id INT NOT NULL,
    person_id INT DEFAULT 0,
    salary NUMERIC(18,4) DEFAULT 0 CHECK (salary >= 0),
    flags INT DEFAULT 0,
    since DATE NOT NULL,
    until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_staff_list_position ON staff_list(position_id);
CREATE INDEX idx_staff_list_dept ON staff_list(dept_id);
CREATE INDEX idx_staff_list_person ON staff_list(person_id);
CREATE INDEX idx_staff_list_dates ON staff_list(since, until);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_staff_list_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_staff_list_update
    BEFORE UPDATE ON staff_list
    FOR EACH ROW
    EXECUTE FUNCTION update_staff_list_timestamp();

-- VIEW: Актуальное штатное расписание
CREATE OR REPLACE VIEW v_current_staff_list AS
SELECT 
    sl.id,
    sl.position_id,
    pos.name AS position_name,
    sl.dept_id,
    d.name AS dept_name,
    sl.person_id,
    p.name AS person_name,
    sl.salary,
    sl.since,
    sl.until
FROM staff_list sl
JOIN position pos ON pos.id = sl.position_id
JOIN department d ON d.id = sl.dept_id
LEFT JOIN person p ON p.id = sl.person_id
WHERE sl.since <= CURRENT_DATE AND (sl.until IS NULL OR sl.until >= CURRENT_DATE)
ORDER BY d.name, pos.name;
