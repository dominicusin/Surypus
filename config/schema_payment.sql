-- ============================================================
-- Payment Tables - Платёжные документы
-- ============================================================

-- Payment methods (способы оплаты)
CREATE TABLE IF NOT EXISTS payment_method (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    code VARCHAR(16) NOT NULL,
    ptype SMALLINT NOT NULL,  -- 0=CASH, 1=CARD, 2=TRANSFER, 3=ONLINE, 4=CHEQUE, 5=BARTER
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Payments (платежи)
CREATE TABLE IF NOT EXISTS payment (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    ptype SMALLINT NOT NULL,
    direction SMALLINT NOT NULL,  -- 0=INCOMING, 1=OUTGOING
    amount NUMERIC(18,2) NOT NULL,
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    rate NUMERIC(18,8) NOT NULL DEFAULT 1,
    amount_in_base NUMERIC(18,2) NOT NULL,
    account_id BIGINT NOT NULL REFERENCES account(id),
    opponent_id BIGINT NOT NULL REFERENCES person(id),
    contract_id BIGINT REFERENCES contract(id),
    bill_id BIGINT REFERENCES bill(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=PREPARED, 2=APPROVED, 3=EXECUTED, 4=CANCELLED, 5=RETURNED
    flags INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    executed_at TIMESTAMPTZ,
    UNIQUE(number)
);

-- Payment lines (позиции платежа - разбивка по документам)
CREATE TABLE IF NOT EXISTS payment_line (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT NOT NULL REFERENCES payment(id),
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    amount NUMERIC(18,2) NOT NULL,
    vat NUMERIC(18,2) DEFAULT 0,
    flags INTEGER DEFAULT 0
);

-- Cash orders (кассовые ордера)
CREATE TABLE IF NOT EXISTS cash_order (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    cotype SMALLINT NOT NULL,  -- 0=RECEIPT, 1=EXPENDITURE
    amount NUMERIC(18,2) NOT NULL,
    cash_register_id BIGINT NOT NULL REFERENCES cash_register(id),
    person_id BIGINT NOT NULL REFERENCES person(id),  -- Кассир
    opponent_id BIGINT REFERENCES person(id),
    status SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

-- Cash registers (кассы)
CREATE TABLE IF NOT EXISTS cash_register (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    location_id BIGINT REFERENCES location(id),
    account_id BIGINT REFERENCES account(id),
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=INACTIVE, 2=CLOSED
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Индексы для платежей
CREATE INDEX IF NOT EXISTS idx_payment_number ON payment(number);
CREATE INDEX IF NOT EXISTS idx_payment_date ON payment(dt);
CREATE INDEX IF NOT EXISTS idx_payment_direction ON payment(direction);
CREATE INDEX IF NOT EXISTS idx_payment_account ON payment(account_id);
CREATE INDEX IF NOT EXISTS idx_payment_opponent ON payment(opponent_id);
CREATE INDEX IF NOT EXISTS idx_payment_status ON payment(status);
CREATE INDEX IF NOT EXISTS idx_payment_bill ON payment(bill_id);

CREATE INDEX IF NOT EXISTS idx_payment_line_payment ON payment_line(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_line_bill ON payment_line(bill_id);

CREATE INDEX IF NOT EXISTS idx_cash_order_number ON cash_order(number);
CREATE INDEX IF NOT EXISTS idx_cash_order_date ON cash_order(dt);
CREATE INDEX IF NOT EXISTS idx_cash_order_register ON cash_order(cash_register_id);
CREATE INDEX IF NOT EXISTS idx_cash_order_status ON cash_order(status);

CREATE INDEX IF NOT EXISTS idx_cash_register_code ON cash_register(code);

-- ============================================================
-- Функции для платежей
-- ============================================================

-- Конвертация в базовую валюту
CREATE OR REPLACE FUNCTION convert_to_base(
    p_amount NUMERIC(18,2),
    p_rate NUMERIC(18,8)
) RETURNS NUMERIC(18,2) AS $$
BEGIN
    RETURN p_amount * p_rate;
END;
$$ LANGUAGE plpgsql;

-- Создать платёж
CREATE OR REPLACE FUNCTION create_payment(
    p_number VARCHAR(48),
    p_date DATE,
    p_ptype SMALLINT,
    p_direction SMALLINT,
    p_amount NUMERIC(18,2),
    p_currency_id BIGINT,
    p_rate NUMERIC(18,8),
    p_account_id BIGINT,
    p_opponent_id BIGINT,
    p_contract_id BIGINT,
    p_bill_id BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO payment (number, dt, ptype, direction, amount, currency_id, rate, amount_in_base, account_id, opponent_id, contract_id, bill_id, status)
    VALUES (p_number, p_date, p_ptype, p_direction, p_amount, p_currency_id, p_rate, p_amount * p_rate, p_account_id, p_opponent_id, p_contract_id, p_bill_id, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Провести платёж
CREATE OR REPLACE FUNCTION execute_payment(p_payment_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE payment 
    SET status = 3, executed_at = NOW()
    WHERE id = p_payment_id AND status = 2;  -- APPROVED
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Создать кассовый ордер
CREATE OR REPLACE FUNCTION create_cash_order(
    p_number VARCHAR(48),
    p_date DATE,
    p_cotype SMALLINT,
    p_amount NUMERIC(18,2),
    p_register_id BIGINT,
    p_person_id BIGINT,
    p_opponent_id BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO cash_order (number, dt, cotype, amount, cash_register_id, person_id, opponent_id, status)
    VALUES (p_number, p_date, p_cotype, p_amount, p_register_id, p_person_id, p_opponent_id, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Провести кассовый ордер
CREATE OR REPLACE FUNCTION execute_cash_order(p_order_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE cash_order 
    SET status = 3, executed_at = NOW()
    WHERE id = p_order_id AND status = 2;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Платёжки за период
CREATE OR REPLACE VIEW v_payments_period AS
SELECT 
    p.id, p.number, p.dt, p.ptype, p.direction, p.amount, p.amount_in_base,
    c.code AS currency_code,
    acc.code AS account_code,
    opp.name AS opponent_name,
    b.number AS bill_number,
    CASE p.direction WHEN 0 THEN 'Приход' ELSE 'Расход' END AS direction_name,
    CASE p.status
        WHEN 0 THEN 'Черновик'
        WHEN 1 THEN 'Подготовлен'
        WHEN 2 THEN 'Утверждён'
        WHEN 3 THEN 'Проведён'
        WHEN 4 THEN 'Отменён'
        WHEN 5 THEN 'Возвращён'
    END AS status_name
FROM payment p
JOIN currency c ON c.id = p.currency_id
JOIN account acc ON acc.id = p.account_id
JOIN person opp ON opp.id = p.opponent_id
LEFT JOIN bill b ON b.id = p.bill_id
WHERE p.dt BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
ORDER BY p.dt DESC;

-- Кассовые ордера
CREATE OR REPLACE VIEW v_cash_orders AS
SELECT 
    co.id, co.number, co.dt, co.cotype, co.amount,
    cr.name AS register_name,
    p.name AS cashier_name,
    opp.name AS opponent_name,
    CASE co.cotype WHEN 0 THEN 'Приходный' ELSE 'Расходный' END AS type_name,
    CASE co.status
        WHEN 0 THEN 'Черновик'
        WHEN 1 THEN 'Подготовлен'
        WHEN 2 THEN 'Утверждён'
        WHEN 3 THEN 'Проведён'
        WHEN 4 THEN 'Отменён'
    END AS status_name
FROM cash_order co
JOIN cash_register cr ON cr.id = co.cash_register_id
JOIN person p ON p.id = co.person_id
LEFT JOIN person opp ON opp.id = co.opponent_id
ORDER BY co.dt DESC;

-- Остаток в кассе
CREATE OR REPLACE VIEW v_cash_register_balance AS
SELECT 
    cr.id, cr.code, cr.name,
    COALESCE(SUM(CASE WHEN co.cotype = 0 THEN co.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN co.cotype = 1 THEN co.amount ELSE 0 END), 0) AS balance
FROM cash_register cr
LEFT JOIN cash_order co ON co.cash_register_id = cr.id AND co.status = 3
GROUP BY cr.id, cr.code, cr.name;

-- Дебиторская задолженность
CREATE OR REPLACE VIEW v_receivables AS
SELECT 
    p.id AS opponent_id, p.name AS opponent_name,
    SUM(pay.amount_in_base) AS total_receivable
FROM payment pay
JOIN person p ON p.id = pay.opponent_id
WHERE pay.direction = 0 AND pay.status = 3  -- INCOMING, EXECUTED
    AND pay.bill_id IS NULL  -- Без привязки к документу
GROUP BY p.id, p.name
HAVING SUM(pay.amount_in_base) > 0;

-- Кредиторская задолженность
CREATE OR REPLACE VIEW v_payables AS
SELECT 
    p.id AS opponent_id, p.name AS opponent_name,
    SUM(pay.amount_in_base) AS total_payable
FROM payment pay
JOIN person p ON p.id = pay.opponent_id
WHERE pay.direction = 1 AND pay.status = 3  -- OUTGOING, EXECUTED
    AND pay.bill_id IS NULL
GROUP BY p.id, p.name
HAVING SUM(pay.amount_in_base) > 0;
