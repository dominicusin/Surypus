-- ============================================================
-- Contract Tables - Договоры
-- ============================================================

-- Contract kinds (виды договоров)
CREATE TABLE IF NOT EXISTS contract_kind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    code VARCHAR(16) NOT NULL,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Contracts (договоры)
CREATE TABLE IF NOT EXISTS contract (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    kind SMALLINT NOT NULL,  -- 0=SUPPLY, 1=PURCHASE, 2=SERVICE, 3=AGENCY, 4=COMMISSION, 5=LEASE, 6=LOAN, 7=PARTNERSHIP, 8=OTHER
    ctype SMALLINT NOT NULL,  -- 0=FRAME, 1=SPECIFIC, 2=SPOT
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=PENDING, 2=ACTIVE, 3=EXPIRED, 4=TERMINATED, 5=COMPLETED
    client_id BIGINT NOT NULL REFERENCES person(id),  -- Контрагент
    our_id BIGINT NOT NULL REFERENCES person(id),     -- Наша организация
    start_date DATE NOT NULL,
    end_date DATE,
    amount NUMERIC(18,2) DEFAULT 0,
    limit_amount NUMERIC(18,2) DEFAULT 0,  -- Лимит
    used_amount NUMERIC(18,2) DEFAULT 0,   -- Использовано
    currency_id BIGINT NOT NULL REFERENCES currency(id),
    flags INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(number)
);

-- Contract lines (позиции договора)
CREATE TABLE IF NOT EXISTS contract_line (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES contract(id),
    line_no INT NOT NULL,
    goods_id BIGINT REFERENCES goods(id),
    service_id BIGINT REFERENCES service(id),
    quantity NUMERIC(18,6) DEFAULT 0,
    price NUMERIC(18,4) DEFAULT 0,
    amount NUMERIC(18,2) DEFAULT 0,
    discount NUMERIC(18,2) DEFAULT 0,
    vat_rate NUMERIC(5,2) DEFAULT 0,
    flags INTEGER DEFAULT 0
);

-- Contract events (события по договору)
CREATE TABLE IF NOT EXISTS contract_event (
    id BIGSERIAL PRIMARY KEY,
    contract_id BIGINT NOT NULL REFERENCES contract(id),
    etype SMALLINT NOT NULL,  -- 0=CREATE, 1=ACTIVATE, 2=AMEND, 3=USE_LIMIT, 4=TERMINATE, 5=COMPLETE
    dt DATE NOT NULL,
    amount NUMERIC(18,2),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для договоров
CREATE INDEX IF NOT EXISTS idx_contract_number ON contract(number);
CREATE INDEX IF NOT EXISTS idx_contract_date ON contract(dt);
CREATE INDEX IF NOT EXISTS idx_contract_kind ON contract(kind);
CREATE INDEX IF NOT EXISTS idx_contract_status ON contract(status);
CREATE INDEX IF NOT EXISTS idx_contract_client ON contract(client_id);
CREATE INDEX IF NOT EXISTS idx_contract_dates ON contract(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_contract_line_contract ON contract_line(contract_id);

CREATE INDEX IF NOT EXISTS idx_contract_event_contract ON contract_event(contract_id);

-- ============================================================
-- Функции для договоров
-- ============================================================

-- Расчёт доступного лимита
CREATE OR REPLACE FUNCTION calc_available_limit(p_contract_id BIGINT)
RETURNS NUMERIC(18,2) AS $$
DECLARE
    v_limit NUMERIC(18,2);
    v_used NUMERIC(18,2);
BEGIN
    SELECT c.limit_amount, c.used_amount INTO v_limit, v_used
    FROM contract c WHERE c.id = p_contract_id;
    
    RETURN v_limit - v_used;
END;
$$ LANGUAGE plpgsql;

-- Использовать лимит
CREATE OR REPLACE FUNCTION use_contract_limit(
    p_contract_id BIGINT,
    p_amount NUMERIC(18,2)
) RETURNS BOOLEAN AS $$
DECLARE
    v_available NUMERIC(18,2);
BEGIN
    v_available := calc_available_limit(p_contract_id);
    
    IF v_available < p_amount THEN
        RETURN FALSE;
    END IF;
    
    UPDATE contract SET used_amount = used_amount + p_amount WHERE id = p_contract_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Освободить лимит
CREATE OR REPLACE FUNCTION release_contract_limit(
    p_contract_id BIGINT,
    p_amount NUMERIC(18,2)
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE contract 
    SET used_amount = GREATEST(0, used_amount - p_amount) 
    WHERE id = p_contract_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Активировать договор
CREATE OR REPLACE FUNCTION activate_contract(p_contract_id BIGINT, p_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE contract SET status = 2, start_date = p_date WHERE id = p_contract_id AND status IN (0, 1);
    
    INSERT INTO contract_event (contract_id, etype, dt, description)
    VALUES (p_contract_id, 1, p_date, 'Активация договора');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Активные договоры
CREATE OR REPLACE VIEW v_active_contracts AS
SELECT 
    c.id, c.number, c.dt, c.kind, c.ctype,
    pc.name AS client_name, po.name AS our_name,
    c.start_date, c.end_date, c.amount, c.limit_amount, c.used_amount,
    calc_available_limit(c.id) AS available_limit,
    CASE c.kind
        WHEN 0 THEN 'Поставка'
        WHEN 1 THEN 'Закупка'
        WHEN 2 THEN 'Услуги'
        WHEN 3 THEN 'Агентский'
        WHEN 4 THEN 'Комиссия'
        WHEN 5 THEN 'Аренда'
        WHEN 6 THEN 'Кредит'
        WHEN 7 THEN 'Партнёрство'
        ELSE 'Прочее'
    END AS kind_name,
    CASE c.ctype
        WHEN 0 THEN 'Рамочный'
        WHEN 1 THEN 'Конкретный'
        WHEN 2 THEN 'Разовый'
    END AS type_name
FROM contract c
JOIN person pc ON pc.id = c.client_id
JOIN person po ON po.id = c.our_id
WHERE c.status = 2  -- ACTIVE
ORDER BY c.end_date;

-- Договоры с истекающим сроком
CREATE OR REPLACE VIEW v_expiring_contracts AS
SELECT 
    c.id, c.number, c.end_date, c.amount,
    pc.name AS client_name,
    c.end_date - CURRENT_DATE AS days_until_expiry
FROM contract c
JOIN person pc ON pc.id = c.client_id
WHERE c.status = 2 AND c.end_date IS NOT NULL
    AND c.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
ORDER BY c.end_date;

-- Лимиты по договорам
CREATE OR REPLACE VIEW v_contract_limits AS
SELECT 
    c.id, c.number, pc.name AS client_name,
    c.limit_amount, c.used_amount, calc_available_limit(c.id) AS available,
    CASE WHEN c.limit_amount = 0 THEN 0 
         ELSE c.used_amount * 100.0 / c.limit_amount 
    END AS usage_percent
FROM contract c
JOIN person pc ON pc.id = c.client_id
WHERE c.status = 2 AND c.limit_amount > 0
ORDER BY usage_percent DESC;
