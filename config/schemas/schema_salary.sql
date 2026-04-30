-- Salary Tables
CREATE TABLE IF NOT EXISTS salary (id BIGSERIAL PRIMARY KEY, employee_id BIGINT NOT NULL, period_start DATE NOT NULL, period_end DATE NOT NULL, amount DECIMAL(18,4) NOT NULL, stype SMALLINT DEFAULT 0, status SMALLINT DEFAULT 0, UNIQUE(employee_id, period_start, period_end));
CREATE INDEX IF NOT EXISTS idx_salary_employee ON salary(employee_id);
