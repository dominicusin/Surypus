-- ============================================================
-- Sales Tables - Продажи (чеки)
-- Соответствует C++ psales.cpp
-- ============================================================

-- Sale (продажа/чек)
CREATE TABLE IF NOT EXISTS sale (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    op_kind_id BIGINT REFERENCES op_kind(id),
    csession_id BIGINT NOT NULL REFERENCES cash_session(id),
    client_id BIGINT REFERENCES person(id),
    warehouse_id BIGINT NOT NULL REFERENCES location(id),
    status SMALLINT DEFAULT 0,  -- 0=DRAFT, 1=OPEN, 2=COMPLETED, 3=RETURNED, 4=CANCELLED
    flags INTEGER DEFAULT 0,
    amount NUMERIC(18,4) DEFAULT 0,   -- Сумма без НДС
    discount NUMERIC(18,4) DEFAULT 0, -- Скидка
    vat NUMERIC(18,4) DEFAULT 0,      -- НДС
    total NUMERIC(18,4) DEFAULT 0,    -- Итого к оплате
    scard_id BIGINT REFERENCES scard(id),  -- Дисконтная карта
    agent_id BIGINT REFERENCES person(id), -- Продавец
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code, csession_id)
);

-- Sale lines (строки чека)
CREATE TABLE IF NOT EXISTS sale_line (
    id BIGSERIAL PRIMARY KEY,
    sale_id BIGINT NOT NULL REFERENCES sale(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    unit_id BIGINT REFERENCES unit(id),
    qtty NUMERIC(18,6) NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(18,4) DEFAULT 0,      -- Скидка на строку
    discount_prc NUMERIC(5,2) DEFAULT 0,   -- Процент скидки
    vat_rate NUMERIC(5,4) DEFAULT 0.2,
    vat NUMERIC(18,4) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(sale_id, line_no)
);

-- Payments (оплаты чека)
CREATE TABLE IF NOT EXISTS payment (
    id BIGSERIAL PRIMARY KEY,
    sale_id BIGINT NOT NULL REFERENCES sale(id) ON DELETE CASCADE,
    ptype SMALLINT NOT NULL,  -- 0=CASH, 1=CARD, 2=CREDIT, 3=PREPAID, 4=GIFT, 5=BONUS
    amount NUMERIC(18,4) NOT NULL,
    card_no VARCHAR(32),
    auth_code VARCHAR(32),
    terminal_id BIGINT REFERENCES device(id),
    dt TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для продаж
CREATE INDEX IF NOT EXISTS idx_sale_csession ON sale(csession_id);
CREATE INDEX IF NOT EXISTS idx_sale_dt ON sale(dt);
CREATE INDEX IF NOT EXISTS idx_sale_client ON sale(client_id);
CREATE INDEX IF NOT EXISTS idx_sale_status ON sale(status);
CREATE INDEX IF NOT EXISTS idx_sale_scard ON sale(scard_id);

CREATE INDEX IF NOT EXISTS idx_sale_line_sale ON sale_line(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_line_goods ON sale_line(goods_id);

CREATE INDEX IF NOT EXISTS idx_payment_sale ON payment(sale_id);
CREATE INDEX IF NOT EXISTS idx_payment_type ON payment(ptype);

-- ============================================================
-- Функции для работы с продажами
-- ============================================================

-- Расчёт суммы продажи
CREATE OR REPLACE FUNCTION sale_calc_amount(p_sale_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_amount NUMERIC(18,4);
    v_vat NUMERIC(18,4);
    v_total NUMERIC(18,4);
BEGIN
    SELECT 
        COALESCE(SUM((sl.qtty * sl.price - sl.discount)), 0),
        COALESCE(SUM((sl.qtty * sl.price - sl.discount) * sl.vat_rate / (1 + sl.vat_rate)), 0)
    INTO v_amount, v_vat
    FROM sale_line sl
    WHERE sl.sale_id = p_sale_id;
    
    v_total := v_amount + v_vat;
    
    UPDATE sale 
    SET amount = v_amount, vat = v_vat, total = v_total, updated_at = NOW()
    WHERE id = p_sale_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер на обновление сумм
CREATE OR REPLACE FUNCTION sale_line_amount_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sale_calc_amount(NEW.sale_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_line_amount
    AFTER INSERT OR UPDATE OR DELETE ON sale_line
    FOR EACH ROW EXECUTE FUNCTION sale_line_amount_trigger();

-- Проверка оплаты и завершение продажи
CREATE OR REPLACE FUNCTION sale_complete(p_sale_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_total NUMERIC(18,4);
    v_paid NUMERIC(18,4);
BEGIN
    SELECT s.total INTO v_total FROM sale s WHERE s.id = p_sale_id;
    SELECT COALESCE(SUM(amount), 0) INTO v_paid FROM payment WHERE sale_id = p_sale_id;
    
    IF v_paid >= v_total THEN
        UPDATE sale SET status = 2, updated_at = NOW() WHERE id = p_sale_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Продажи за день
CREATE OR REPLACE VIEW v_sales_by_day AS
SELECT 
    DATE(s.dt) AS sale_date,
    COUNT(*) AS sale_count,
    SUM(s.amount) AS total_amount,
    SUM(s.discount) AS total_discount,
    SUM(s.vat) AS total_vat,
    SUM(s.total) AS total
FROM sale s
WHERE s.status = 2
GROUP BY DATE(s.dt)
ORDER BY sale_date DESC;

-- Продажи по товарам
CREATE OR REPLACE VIEW v_sales_by_goods AS
SELECT 
    s.dt,
    s.code AS sale_code,
    sl.line_no,
    g.id AS goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    sl.qtty,
    sl.price,
    sl.discount,
    sl.qtty * sl.price - sl.discount AS line_amount,
    sl.vat
FROM sale s
JOIN sale_line sl ON sl.sale_id = s.id
JOIN goods g ON g.id = sl.goods_id
WHERE s.status = 2
ORDER BY s.dt, sl.line_no;

-- Продажи по кассирам
CREATE OR REPLACE VIEW v_sales_by_agent AS
SELECT 
    s.dt,
    a.id AS agent_id,
    a.name AS agent_name,
    COUNT(*) AS sale_count,
    SUM(s.total) AS total
FROM sale s
JOIN person a ON a.id = s.agent_id
WHERE s.status = 2
GROUP BY s.dt, a.id, a.name
ORDER BY s.dt;

-- Оплаты по типам
CREATE OR REPLACE VIEW v_payments_by_type AS
SELECT 
    DATE(p.dt) AS pay_date,
    p.ptype,
    COUNT(*) AS pay_count,
    SUM(p.amount) AS total
FROM payment p
GROUP BY DATE(p.dt), p.ptype
ORDER BY pay_date DESC;

-- Частичные возвраты за период
CREATE OR REPLACE VIEW v_returns_by_period AS
SELECT 
    s.id,
    s.code,
    s.dt,
    s.client_id,
    p.name AS client_name,
    s.total AS return_amount,
    s.status
FROM sale s
LEFT JOIN person p ON p.id = s.client_id
WHERE s.status = 3
ORDER BY s.dt DESC;
