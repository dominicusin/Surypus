-- ============================================================================
-- Хранимые процедуры для кадрового учёта и зарплаты
-- PostgreSQL реализация бизнес-логики OpenPapyrus
-- ============================================================================

-- ============================================================================
-- ТАБЛИЦЫ
-- ============================================================================

-- Должности
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category INTEGER DEFAULT 0,  -- PC_WORKER, PC_EMPLOYEE, etc.
    salary NUMERIC(15,2) DEFAULT 0,
    flags INTEGER DEFAULT 0
);

-- Штатные единицы
CREATE TABLE IF NOT EXISTS staff_units (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts(id),
    person_id INTEGER,  -- NULL если вакансия
    location_id INTEGER NOT NULL REFERENCES locations(id),
    flags INTEGER DEFAULT 0,
    valid_from DATE DEFAULT CURRENT_DATE,
    valid_to DATE DEFAULT '2099-12-31'
);

-- Сотрудники
CREATE TABLE IF NOT EXISTS persons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    inn VARCHAR(12),
    snils VARCHAR(14),
    flags INTEGER DEFAULT 0,  -- PSNF_NOVATAX и др.
    birth_date DATE,
    hire_date DATE,
    fire_date DATE
);

-- Виды начислений
CREATE TABLE IF NOT EXISTS salary_charges (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    charge_type INTEGER NOT NULL,  -- CT_SALARY, CT_PREMIUM, etc.
    formula_type INTEGER NOT NULL, -- SF_FIXED, SF_PERCENT, etc.
    formula_value NUMERIC(15,4),   -- Значение формулы
    taxable BOOLEAN DEFAULT TRUE,
    e_contrib BOOLEAN DEFAULT TRUE
);

-- Виды удержаний
CREATE TABLE IF NOT EXISTS salary_accruals (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    accrual_type INTEGER NOT NULL,  -- AT_NDFL, AT_INSURANCE, etc.
    formula_type INTEGER NOT NULL,
    formula_value NUMERIC(15,4)
);

-- Начисления сотрудникам
CREATE TABLE IF NOT EXISTS salary_records (
    id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES persons(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    charge_id INTEGER NOT NULL REFERENCES salary_charges(id),
    amount NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Табель учёта рабочего времени
CREATE TABLE IF NOT EXISTS timesheet (
    id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES persons(id),
    work_date DATE NOT NULL,
    hours INTEGER NOT NULL,
    time_type INTEGER NOT NULL,  -- TT_WORKDAYS, TT_VACATION, etc.
    UNIQUE(person_id, work_date)
);

-- Отпуска
CREATE TABLE IF NOT EXISTS vacations (
    id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES persons(id),
    vacation_type INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days_count INTEGER NOT NULL,
    amount NUMERIC(15,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ПРОЦЕДУРЫ РАСЧЁТА ЗАРПЛАТЫ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Расчёт НДФЛ
-- Теорема: НДФЛ = (Доход - Вычеты) * Ставка / 100
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_ndfl(
    p_income NUMERIC(15,2),
    p_deductions NUMERIC(15,2),
    p_rate NUMERIC(5,2) DEFAULT 13
)
RETURNS NUMERIC(15,2) AS $$
BEGIN
    IF p_income <= 0 THEN
        RETURN 0;
    END IF;
    
    DECLARE
        v_taxable NUMERIC(15,2) := GREATEST(0, p_income - p_deductions);
    BEGIN
        RETURN ROUND(v_taxable * p_rate / 100, 2);
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Расчёт НДФЛ по прогрессивной шкале (2024)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_ndfl_progressive(p_annual_income NUMERIC(15,2))
RETURNS NUMERIC(15,2) AS $$
BEGIN
    IF p_annual_income <= 5000000 THEN
        -- 13% до 5 млн
        RETURN ROUND(p_annual_income * 0.13, 2);
    ELSE
        -- 650 тыс + 15% от превышения
        RETURN 650000 + ROUND((p_annual_income - 5000000) * 0.15, 2);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Расчёт страховых взносов
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_insurance_contributions(p_income NUMERIC(15,2))
RETURNS TABLE (
    pension NUMERIC(15,2),
    medical NUMERIC(15,2),
    social NUMERIC(15,2),
    accident NUMERIC(15,2)
) AS $$
BEGIN
    RETURN QUERY SELECT
        ROUND(p_income * 0.22, 2),  -- Пенсионный 22%
        ROUND(p_income * 0.051, 2), -- Медицинский 5.1%
        ROUND(p_income * 0.029, 2), -- Социальный 2.9%
        ROUND(p_income * 0.002, 2); -- Несчастные случаи 0.2%
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Полный расчёт зарплаты сотрудника за период
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_person_salary(
    p_person_id INTEGER,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE (
    charge_id INTEGER,
    charge_name VARCHAR,
    amount NUMERIC(15,2),
    accrual_id INTEGER,
    accrual_name VARCHAR,
    accrual_amount NUMERIC(15,2),
    ndfl NUMERIC(15,2),
    total_charges NUMERIC(15,2),
    total_accruals NUMERIC(15,2),
    net_salary NUMERIC(15,2)
) AS $$
DECLARE
    v_total_charges NUMERIC(15,2) := 0;
    v_total_accruals NUMERIC(15,2) := 0;
    v_ndfl NUMERIC(15,2) := 0;
    v_deductions NUMERIC(15,2) := 0;
    v_record RECORD;
BEGIN
    -- Сумма начислений
    SELECT COALESCE(SUM(amount), 0) INTO v_total_charges
    FROM salary_records
    WHERE person_id = p_person_id
      AND period_start >= p_period_start
      AND period_end <= p_period_end;
    
    -- Сумма вычетов
    SELECT COALESCE(SUM(td.amount), 0) INTO v_deductions
    FROM tax_deductions td
    WHERE td.person_id = p_person_id
      AND td.period_start <= p_period_end
      AND td.period_end >= p_period_start;
    
    -- Расчёт НДФЛ
    v_ndfl := calc_ndfl(v_total_charges, v_deductions, 13);
    
    -- Сумма удержаний (кроме НДФЛ)
    SELECT COALESCE(SUM(amount), 0) INTO v_total_accruals
    FROM salary_accruals_records
    WHERE person_id = p_person_id
      AND accrual_type <> 1;  -- Кроме НДФЛ
    
    RETURN QUERY
    SELECT 
        NULL::INTEGER,
        NULL::VARCHAR,
        NULL::NUMERIC(15,2),
        NULL::INTEGER,
        NULL::VARCHAR,
        NULL::NUMERIC(15,2),
        v_ndfl,
        v_total_charges,
        v_total_accruals + v_ndfl,
        v_total_charges - v_total_accruals - v_ndfl;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Расчёт отпускных
-- Средний заработок = Σ зарплата за 12 мес / 12 / 29.3
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_vacation_pay(
    p_person_id INTEGER,
    p_vacation_days INTEGER
)
RETURNS NUMERIC(15,2) AS $$
DECLARE
    v_avg_daily NUMERIC(15,4);
    v_total_salary NUMERIC(15,2);
BEGIN
    -- Сумма зарплаты за последние 12 месяцев
    SELECT COALESCE(SUM(amount), 0) INTO v_total_salary
    FROM salary_records
    WHERE person_id = p_person_id
      AND period_start >= CURRENT_DATE - INTERVAL '12 months'
      AND charge_id IN (
          SELECT id FROM salary_charges WHERE charge_type IN (1, 2, 3)
      );
    
    -- Средний дневной заработок
    v_avg_daily := v_total_salary / 12 / 29.3;
    
    RETURN ROUND(v_avg_daily * p_vacation_days, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Табель: расчёт рабочих часов за период
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_timesheet_hours(
    p_person_id INTEGER,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS TABLE (
    work_date DATE,
    hours INTEGER,
    time_type_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.work_date,
        t.hours,
        CASE t.time_type
            WHEN 1 THEN 'Рабочие дни'
            WHEN 2 THEN 'Выходные'
            WHEN 3 THEN 'Праздники'
            WHEN 4 THEN 'Отпуск'
            WHEN 5 THEN 'Больничный'
            ELSE 'Прочее'
        END
    FROM timesheet t
    WHERE t.person_id = p_person_id
      AND t.work_date BETWEEN p_period_start AND p_period_end
    ORDER BY t.work_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Проверка пересечения отпусков
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_vacation_overlap(
    p_person_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM vacations
    WHERE person_id = p_person_id
      AND (
          (start_date <= p_end_date AND end_date >= p_start_date)
      );
    
    RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Создание начисления зарплаты
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_salary_charge(
    p_person_id INTEGER,
    p_charge_id INTEGER,
    p_period_start DATE,
    p_period_end DATE,
    p_amount NUMERIC(15,2)
)
RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO salary_records 
        (person_id, period_start, period_end, charge_id, amount)
    VALUES 
        (p_person_id, p_period_start, p_period_end, p_charge_id, p_amount)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ ДАННЫХ
-- ============================================================================

-- Виды начислений
INSERT INTO salary_charges (name, charge_type, formula_type, formula_value, taxable, e_contrib) VALUES
    ('Оклад (тариф)', 1, 2, NULL, TRUE, TRUE),
    ('Сдельная оплата', 2, 5, NULL, TRUE, TRUE),
    ('Премия', 3, 3, 10, TRUE, TRUE),
    ('Бонус', 4, 1, 0, TRUE, TRUE),
    ('Оплата отпуска', 5, 2, NULL, TRUE, TRUE),
    ('Оплата больничного', 6, 2, NULL, TRUE, FALSE)
ON CONFLICT DO NOTHING;

-- Виды удержаний
INSERT INTO salary_accruals (name, accrual_type, formula_type, formula_value) VALUES
    ('НДФЛ', 1, 1, 13),
    ('Аванс', 4, 2, 0),
    ('Штраф', 5, 2, 0),
    ('Профсоюзный взнос', 6, 1, 1)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
    RAISE NOTICE 'HR and Salary database schema created successfully';
END $$;
