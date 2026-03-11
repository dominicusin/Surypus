-- =============================================================================
-- ДОКУМЕНТЫ (Document)
-- Соответствуют Core.Document.Document
-- =============================================================================

-- Типы документов
CREATE TABLE IF NOT EXISTS doc_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    op_type_id INT,
    flags INT DEFAULT 0
);

INSERT INTO doc_types (code, name, op_type_id) VALUES
    ('GOODS_RECEIPT', 'Приходная накладная', 1),
    ('GOODS_SHIPMENT', 'Расходная накладная', 2),
    ('GOODS_RETURN', 'Возврат поставщику', 3),
    ('SALE_RETURN', 'Возврат от покупателя', 4),
    ('ORDER', 'Заказ', 5),
    ('PREORDER', 'Предзаказ', 6),
    ('WASTE', 'Списание', 7),
    ('PCKGT_RETURN', 'Возврат упаковки', 8),
    ('ACCTURN', 'Бухгалтерская проводка', 9),
    ('CREDIT_NOTE', 'Кредит-нота', 10),
    ('DEBIT_NOTE', 'Дебет-нота', 11),
    ('PAYMENT', 'Платёж', 12),
    ('CASH_ORDER', 'Кассовый ордер', 13),
    ('BANK_ORDER', 'Банковский ордер', 14)
ON CONFLICT DO NOTHING;

-- Таблица документов
CREATE TABLE IF NOT EXISTS bills (
    id SERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    dt DATE NOT NULL,
    op_id INT NOT NULL,
    object_id INT,  -- контрагент
    location_id INT,
    amount NUMERIC(15,2) DEFAULT 0,
    vat NUMERIC(15,2) DEFAULT 0,
    discount NUMERIC(15,2) DEFAULT 0,
    flags INT DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_bills_code ON bills(code);
CREATE INDEX idx_bills_dt ON bills(dt);
CREATE INDEX idx_bills_op ON bills(op_id);
CREATE INDEX idx_bills_object ON bills(object_id);

-- Таблица строк документов
CREATE TABLE IF NOT EXISTS bill_lines (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(15,4) NOT NULL CHECK (quantity >= 0),
    price NUMERIC(15,4) NOT NULL CHECK (price >= 0),
    cost NUMERIC(15,4) DEFAULT 0 CHECK (cost >= 0),
    discount NUMERIC(15,2) DEFAULT 0 CHECK (discount >= 0),
    vat_rate NUMERIC(5,2) DEFAULT 0 CHECK (vat_rate >= 0),
    vat_sum NUMERIC(15,2) DEFAULT 0 CHECK (vat_sum >= 0),
    flags INT DEFAULT 0,
    location_id INT,
    warehouse_id INT,
    line_no INT DEFAULT 0
);

CREATE INDEX idx_bill_lines_bill ON bill_lines(bill_id);
CREATE INDEX idx_bill_lines_goods ON bill_lines(goods_id);

-- Триггер для проверки сумм строк
CREATE OR REPLACE FUNCTION check_bill_totals()
RETURNS TRIGGER AS $$
DECLARE
    total NUMERIC(15,2);
    line_total NUMERIC(15,2);
BEGIN
    -- Рассчитать сумму строк
    SELECT COALESCE(SUM(quantity * price - discount), 0) + COALESCE(SUM(vat_sum), 0)
    INTO line_total
    FROM bill_lines
    WHERE bill_id = NEW.id;
    
    -- Рассчитать сумму документа
    SELECT amount INTO total FROM bills WHERE id = NEW.id;
    
    -- Проверить совпадение (с точностью до копейки)
    IF ABS(total - line_total) > 0.01 THEN
        RAISE EXCEPTION 'Bill total (%) does not match sum of lines (%)', total, line_total;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Кассовые чеки
CREATE TABLE IF NOT EXISTS cash_checks (
    id SERIAL PRIMARY KEY,
    code VARCHAR(48),
    dt TIMESTAMP NOT NULL,
    session_id INT NOT NULL,
    total NUMERIC(15,2) DEFAULT 0,
    discount NUMERIC(15,2) DEFAULT 0,
    vat NUMERIC(15,2) DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cash_checks_dt ON cash_checks(dt);
CREATE INDEX idx_cash_checks_session ON cash_checks(session_id);

-- Строки чеков
CREATE TABLE IF NOT EXISTS cash_check_lines (
    id SERIAL PRIMARY KEY,
    check_id INT NOT NULL REFERENCES cash_checks(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(15,4) NOT NULL,
    price NUMERIC(15,4) NOT NULL,
    discount NUMERIC(15,2) DEFAULT 0,
    flags INT DEFAULT 0,
    line_no INT DEFAULT 0
);

CREATE INDEX idx_cash_check_lines_check ON cash_check_lines(check_id);

-- Кассовые сессии
CREATE TABLE IF NOT EXISTS cash_sessions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(48),
    dt DATE NOT NULL,
    cash_node_id INT NOT NULL,
    user_id INT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    cash_in NUMERIC(15,2) DEFAULT 0,
    cash_out NUMERIC(15,2) DEFAULT 0,
    total_sales NUMERIC(15,2) DEFAULT 0,
    total_return NUMERIC(15,2) DEFAULT 0,
    checks_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cash_sessions_dt ON cash_sessions(dt);
CREATE INDEX idx_cash_sessions_cash_node ON cash_sessions(cash_node_id);

-- Функция расчёта итогов документа
CREATE OR REPLACE FUNCTION calc_bill_total(p_bill_id INT)
RETURNS TABLE(total NUMERIC, vat NUMERIC, discount NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(bl.quantity * bl.price - bl.discount), 0) + COALESCE(SUM(bl.vat_sum), 0) AS total,
        COALESCE(SUM(bl.vat_sum), 0) AS vat,
        COALESCE(SUM(bl.discount), 0) AS discount
    FROM bill_lines bl
    WHERE bl.bill_id = p_bill_id;
END;
$$ LANGUAGE plpgsql;
