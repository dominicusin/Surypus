-- ============================================================
-- Accounting Tables - Бухгалтерский учёт
-- Соответствует C++ acct.cpp, accturn.cpp
-- ============================================================

-- Account sheets (планы счетов)
CREATE TABLE IF NOT EXISTS acc_sheet (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    stype SMALLINT NOT NULL DEFAULT 0,  -- 0=RUSSIAN, 1=USGAAP, 2=IFRS, 3=CUSTOM
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Accounts (счета)
CREATE TABLE IF NOT EXISTS account (
    id BIGSERIAL PRIMARY KEY,
    sheet_id BIGINT NOT NULL REFERENCES acc_sheet(id),
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    atype SMALLINT NOT NULL DEFAULT 0,  -- 0=ASSET, 1=LIABILITY, 2=BOTH, 3=OFFBALANCE
    parent_id BIGINT REFERENCES account(id),
    currency_id BIGINT REFERENCES currency(id),
    flags INTEGER DEFAULT 0,
    balance NUMERIC(18,4) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(sheet_id, code)
);

-- Accounting entries (проводки)
CREATE TABLE IF NOT EXISTS acct_entry (
    id BIGSERIAL PRIMARY KEY,
    dt DATE NOT NULL,
    bill_id BIGINT REFERENCES bill(id),
    op_kind_id BIGINT REFERENCES op_kind(id),
    description TEXT,
    debit_acc_id BIGINT NOT NULL REFERENCES account(id),
    credit_acc_id BIGINT NOT NULL REFERENCES account(id),
    amount NUMERIC(18,4) NOT NULL,
    currency_id BIGINT REFERENCES currency(id),
    currency_rate NUMERIC(18,9) DEFAULT 1,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CHECK (debit_acc_id <> credit_acc_id)
);

-- Индексы для бухгалтерии
CREATE INDEX IF NOT EXISTS idx_account_sheet ON account(sheet_id);
CREATE INDEX IF NOT EXISTS idx_account_code ON account(code);
CREATE INDEX IF NOT EXISTS idx_account_parent ON account(parent_id);

CREATE INDEX IF NOT EXISTS idx_acct_entry_dt ON acct_entry(dt);
CREATE INDEX IF NOT EXISTS idx_acct_entry_bill ON acct_entry(bill_id);
CREATE INDEX IF NOT EXISTS idx_acct_entry_debit ON acct_entry(debit_acc_id);
CREATE INDEX IF NOT EXISTS idx_acct_entry_credit ON acct_entry(credit_acc_id);

-- ============================================================
-- Функции для бухгалтерии
-- ============================================================

-- Расчёт оборотов по счёту за период
CREATE OR REPLACE FUNCTION account_turnover(
    p_account_id BIGINT, 
    p_date_from DATE, 
    p_date_to DATE
) RETURNS TABLE (
    debit_turnover NUMERIC(18,4),
    credit_turnover NUMERIC(18,4),
    balance NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN ae.debit_acc_id = p_account_id THEN ae.amount ELSE 0 END), 0) AS debit_turnover,
        COALESCE(SUM(CASE WHEN ae.credit_acc_id = p_account_id THEN ae.amount ELSE 0 END), 0) AS credit_turnover,
        COALESCE(SUM(CASE WHEN ae.debit_acc_id = p_account_id THEN ae.amount ELSE -ae.amount END), 0) AS balance
    FROM acct_entry ae
    WHERE ae.dt >= p_date_from AND ae.dt <= p_date_to;
END;
$$ LANGUAGE plpgsql;

-- Оборотно-сальдовая ведомость
CREATE OR REPLACE FUNCTION trial_balance(p_sheet_id BIGINT, p_date DATE)
RETURNS TABLE (
    account_id BIGINT,
    account_code VARCHAR(32),
    account_name VARCHAR(256),
    debit_start NUMERIC(18,4),
    credit_start NUMERIC(18,4),
    debit_turnover NUMERIC(18,4),
    credit_turnover NUMERIC(18,4),
    debit_end NUMERIC(18,4),
    credit_end NUMERIC(18,4)
) AS $$
DECLARE
    v_date_from DATE;
BEGIN
    v_date_from := DATE_TRUNC('YEAR', p_date);
    
    RETURN QUERY
    SELECT 
        a.id,
        a.code,
        a.name,
        COALESCE(SUM(CASE WHEN ae.dt < v_date_from AND ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN ae.dt < v_date_from AND ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS debit_start,
        COALESCE(SUM(CASE WHEN ae.dt < v_date_from AND ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN ae.dt < v_date_from AND ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS credit_start,
        COALESCE(SUM(CASE WHEN ae.dt >= v_date_from AND ae.dt <= p_date AND ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS debit_turnover,
        COALESCE(SUM(CASE WHEN ae.dt >= v_date_from AND ae.dt <= p_date AND ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS credit_turnover,
        0::NUMERIC(18,4) AS debit_end,
        0::NUMERIC(18,4) AS credit_end
    FROM account a
    LEFT JOIN acct_entry ae ON ae.debit_acc_id = a.id OR ae.credit_acc_id = a.id
    WHERE a.sheet_id = p_sheet_id
    GROUP BY a.id, a.code, a.name
    ORDER BY a.code;
END;
$$ LANGUAGE plpgsql;

-- Автоматическое создание проводок по виду операции
CREATE OR REPLACE FUNCTION create_acct_entries(p_bill_id BIGINT, p_op_kind_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_op_kind RECORD;
    v_bill RECORD;
    v_amount NUMERIC(18,4);
BEGIN
    -- Получить вид операции
    SELECT * INTO v_op_kind FROM op_kind WHERE id = p_op_kind_id;
    
    -- Получить документ
    SELECT * INTO v_bill FROM bill WHERE id = p_bill_id;
    
    IF v_op_kind.acc_sheet_id IS NOT NULL THEN
        v_amount := v_bill.amount;
        
        -- Создать проводку
        INSERT INTO acct_entry (dt, bill_id, op_kind_id, debit_acc_id, credit_acc_id, amount)
        VALUES (v_bill.dt, v_bill.id, v_op_kind.id, 
                v_op_kind.acc_sheet_id, v_op_kind.acc_sheet2_id, v_amount);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Обороты за день
CREATE OR REPLACE VIEW v_daily_entries AS
SELECT 
    ae.dt,
    ae.bill_id,
    b.code AS bill_code,
    ae.op_kind_id,
    ok.name AS op_kind_name,
    da.code AS debit_code,
    da.name AS debit_name,
    ca.code AS credit_code,
    ca.name AS credit_name,
    ae.amount,
    ae.description
FROM acct_entry ae
JOIN account da ON da.id = ae.debit_acc_id
JOIN account ca ON ca.id = ae.credit_acc_id
LEFT JOIN bill b ON b.id = ae.bill_id
LEFT JOIN op_kind ok ON ok.id = ae.op_kind_id
ORDER BY ae.dt DESC, ae.id;

-- Журнал проводок
CREATE OR REPLACE VIEW v_entries_journal AS
SELECT 
    ae.id,
    ae.dt,
    ae.bill_id,
    b.code AS bill_code,
    ok.name AS operation,
    ae.description,
    da.code AS debit,
    da.name AS debit_name,
    ca.code AS credit,
    ca.name AS credit_name,
    ae.amount,
    ae.currency_id,
    ae.currency_rate
FROM acct_entry ae
JOIN account da ON da.id = ae.debit_acc_id
JOIN account ca ON ca.id = ae.credit_acc_id
LEFT JOIN bill b ON b.id = ae.bill_id
LEFT JOIN op_kind ok ON ok.id = ae.op_kind_id
ORDER BY ae.dt, ae.id;

-- Сальдо по счетам
CREATE OR REPLACE VIEW v_account_balances AS
SELECT 
    a.id,
    a.code,
    a.name,
    a.atype,
    a.sheet_id,
    SUM(CASE WHEN ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END) AS total_debit,
    SUM(CASE WHEN ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END) AS total_credit,
    SUM(CASE WHEN ae.debit_acc_id = a.id THEN ae.amount ELSE -ae.amount END) AS balance
FROM account a
LEFT JOIN acct_entry ae ON ae.debit_acc_id = a.id OR ae.credit_acc_id = a.id
GROUP BY a.id, a.code, a.name, a.atype, a.sheet_id
ORDER BY a.code;
