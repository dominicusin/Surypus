-- =============================================================================
-- HR Payroll Tables - Перенос salary.cpp
-- =============================================================================

CREATE TABLE IF NOT EXISTS hr_salary_charge (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(64) UNIQUE,
    flags INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS hr_salary (
    id SERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employee(id) ON DELETE CASCADE,
    charge_id BIGINT NOT NULL REFERENCES hr_salary_charge(id) ON DELETE CASCADE,
    ext_obj_id BIGINT DEFAULT 0,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    amount NUMERIC(18,2) NOT NULL CHECK (amount >= 0),
    flags INT DEFAULT 0,
    link_bill_id BIGINT DEFAULT 0,
    gen_bill_id BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_salary_period
    ON hr_salary(employee_id, charge_id, period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_hr_salary_employee ON hr_salary(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_charge ON hr_salary(charge_id);

-- =============================================================================
-- HR Payroll functions
-- =============================================================================

CREATE OR REPLACE FUNCTION create_salary_record(
    p_employee_id BIGINT,
    p_charge_id BIGINT,
    p_period_start DATE,
    p_period_end DATE,
    p_amount NUMERIC,
    p_ext_obj_id BIGINT DEFAULT 0,
    p_link_bill_id BIGINT DEFAULT 0,
    p_gen_bill_id BIGINT DEFAULT 0
)
RETURNS BIGINT AS $$
DECLARE
    v_conflict BIGINT;
BEGIN
    IF p_period_start > p_period_end THEN
        RAISE EXCEPTION 'period mismatch: % > %', p_period_start, p_period_end;
    END IF;
    IF p_amount < 0 THEN
        RAISE EXCEPTION 'amount must be non-negative';
    END IF;
    SELECT id INTO v_conflict
    FROM hr_salary
    WHERE employee_id = p_employee_id
      AND charge_id = p_charge_id
      AND NOT (period_end < p_period_start OR period_start > p_period_end)
    LIMIT 1;
    IF v_conflict IS NOT NULL THEN
        RAISE EXCEPTION 'overlapping salary record % for employee % and charge %', v_conflict, p_employee_id, p_charge_id;
    END IF;

    INSERT INTO hr_salary (employee_id, charge_id, period_start, period_end, amount, ext_obj_id, link_bill_id, gen_bill_id)
    VALUES (p_employee_id, p_charge_id, p_period_start, p_period_end, p_amount, p_ext_obj_id, p_link_bill_id, p_gen_bill_id)
    RETURNING id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calc_salary_sum(
    p_employee_id BIGINT,
    p_charge_id BIGINT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS NUMERIC AS $$
DECLARE
    v_sum NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_sum
    FROM hr_salary
    WHERE employee_id = p_employee_id
      AND charge_id = p_charge_id
      AND period_start >= p_period_start
      AND period_end <= p_period_end;
    RETURN v_sum;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION hr_payroll_summary(
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE (
    employee_id BIGINT,
    employee_name TEXT,
    position_name TEXT,
    total_salary NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        p.name,
        pos.name,
        COALESCE(SUM(s.amount), 0)
    FROM employee e
    JOIN person p ON p.id = e.person_id
    JOIN position pos ON pos.id = e.position_id
    LEFT JOIN hr_salary s ON s.employee_id = e.id
      AND s.period_start >= p_period_start
      AND s.period_end <= p_period_end
    WHERE e.status = 0
    GROUP BY e.id, p.name, pos.name
    ORDER BY total_salary DESC;
END;
$$ LANGUAGE plpgsql;
